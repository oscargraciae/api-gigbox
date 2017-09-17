class Api::V1::RequestServicesController < BaseController
    before_filter :auth, only: [:index, :show, :create, :jobs, :accept, :finish, :status, :cancel]

    def index
        requests = []

        if params[:status_id] === '3'
            requests = RequestService.request_history(@user.id)
        elsif params[:status_id] === '2'
            requests = RequestService.pending_request(@user.id)
        else
            requests = RequestService.requests_by_status(@user.id, params[:status_id])
        end

        render json: requests, status: :ok
    end

    def jobs
        jobs = []

        jobs = if params[:status_id] === '3'
                   RequestService.jobs_history(@user.id, params[:status_id])
               elsif params[:status_id] === '2'
                   RequestService.pending_jobs(@user.id, params[:status_id])
               else
                   RequestService.jobs_by_status(@user.id, params[:status_id])
               end

        render json: jobs, status: :ok
    end

    def show
        request = RequestService.find(params[:id])
        render json: request, status: :ok
    end

    def create
        request = RequestService.new(request_params)
        card = CreditCard.find(params[:card_id])
        service = Service.find(request.service_id)

        package = Package.find(params[:package_id]) if params[:package_id]

        if package
            price_by_package(package)
            request.price = package.price
            request.package_id = package.id
        else
            price_by_service(service)
            request.price = service.price
        end

        request.quantity = @unit_size
        request.subtotal = @subtotal
        request.fee = @fee_general
        request.total = @total

        request.supplier_id = service.user_id
        request.token_card = card.token

        if request.save
            create_notification(request, 'ha solicitado el servicio', request.user, request.supplier)
            reply(request, 'ha solicitado el servicio', request.user, request.supplier)
            # Metodo de envio de correo
            # supplier = User.find(service.user_id)
            # PurchaseDetail.send_purchase_detail(@user, request, service, supplier).deliver

            render json: request, status: :ok
        else
            render json: 'Error', status: 422
       end
    end

    def update_payment_method
      request = RequestService.find(params[:id])
      card = CreditCard.find(params[:card_id])
      if request.update_attributes(token_card: card.token, is_declined_card: false)
        create_notification(request, 'ha actualizado su forma de pago', request.user, request.supplier)
        render json: request, status: :ok
      end
    end

    def accept
        @request = RequestService.joins(:service).find(params[:id])

        is_paid = payment_conekta

        @request.update_attribute(:is_declined_card, true) unless is_paid

        if @message_error
            create_notification(@request, @message_error.message_to_purchaser, @request.supplier, @request.user)

            render json: @message_error, status: 200
        else

            if @request.update_attribute(:request_status_id, REQUEST_STATUS_INPROCESS)
                create_notification(@request, 'acepto el trabajo', @request.supplier, @request.user)
                Order.create(@request.id, ORDER_STATUS_PENDING, @request.price, @request.fee)
                render json: @request, status: :ok
            end

        end
    end

    def finish
        request = RequestService.find(params[:id])

        if params[:finish_type] == 'supplier'
            request = finish_supplier(request)
        elsif params[:finish_type] == 'customer'
            request = finish_customer(request)
        end

        render json: request, status: :ok
    end

    def status
        request = RequestService.find(params[:id])

        if request.update_attribute(:request_status_id, params[:status_id])
            req_status = RequestStatus.find(params[:status_id])
            render json: request, status: :ok
        end
    end

    def cancel
        request = RequestService.find(params[:id])

        user_id_cancel = Integer(params[:user_id])
        user_cancel = nil
        user_id_notifier = 0
        user_notifier = nil

        user_cancel = User.find(params[:user_id])

        if user_id_cancel == request.supplier.id
            user_id_notifier = request.user.id
            user_notifier = request.user
        else
            user_id_notifier = request.supplier.id
            user_notifier = request.supplier
        end

        if request.update_attribute(:request_status_id, REQUEST_STATUS_CANCELED)
            order = Order.find_by(request_service_id: request.id)
            order.update_attribute(:order_status_id, ORDER_STATUS_CANCELED) if order

            create_notification(request, 'canceló el trabajo', user_cancel, user_notifier)
            render json: request, status: :ok
        else
            render json: { error: 'Ocurrió un error.' }, status: 500
        end
    end

    def calculate_cost
        if params[:service_id]
            service = Service.find(params[:service_id])
            price_by_service(service)
        elsif params[:package_id]
            package = Package.find(params[:package_id])
            price_by_package(package)
        end

        render json: { subtotal: @subtotal, fee: @fee, total: @total, fee_general: @fee_general, fee_IVA: @fee_IVA }, status: :ok
    end

    def request_params
        params.permit(:request_date, :request_time, :message, :user_id, :service_id)
    end

    # Metodo para calcular el costo de la solicitud por servicio

    private

    def price_by_service(service)
        # Validamos si el servicio tiene unidades de medida
        if service.unit_type_id.present?
            if service.unit_max > 0
                subtotal = service.price * Integer(params[:unit_size])
            end
        else
            subtotal = service.price
        end

        get_price(subtotal)
    end

    # Metodo para calcular el costo de la solicitud por paquete

    private

    def price_by_package(package)
        if package.unit_type_id.present?
            if package.unit_max > 0
                subtotal = package.price * Integer(params[:unit_size])
            end
        else
            subtotal = package.price
        end

        get_price(subtotal)
    end

    def get_price(subtotal)
        fee, fee_IVA = calculate_fee(subtotal)
        fee_conekta = conekta_fee(fee + subtotal)

        @unit_size = params[:unit_size].nil? ? 0 : params[:unit_size]
        @subtotal = subtotal.round(2)
        @fee = (fee + fee_conekta).round(2)
        @fee_IVA = fee_IVA.round(2)
        @fee_general = (@fee + @fee_IVA).round(2)
        @total = (@subtotal + @fee + @fee_IVA).round(2)
    end

    private

    def finish_customer(request)
        create_notification(request, 'aprobó el trabajo', request.user, request.supplier)

        request.update_attributes(is_finish_customer: true, request_status_id: REQUEST_STATUS_FINISH)

        request_size = RequestService.where(service_id: request.service_id, request_status_id: REQUEST_STATUS_FINISH).size
        s = Service.find(request.service_id)
        s.update_attribute(:total_jobs, request_size)

        request
    end

    private

    def finish_supplier(request)
        create_notification(request, 'ha terminado', request.supplier, request.user)
        request.update_attribute(:is_finish_supplier, true)
        request
    end

    private

    def payment_conekta
        # @charge = Conekta::Charge.create('amount' => (@request.total * 100).to_i,
        #                                  'currency' => 'MXN',
        #                                  'description' => @request.message,
        #                                  'reference_id' => @request.id,
        #                                  'card' => @request.token_card,
        #                                  'details' => {
        #                                      'name' => @user.first_name,
        #                                      'phone' => '8182002386',
        #                                      'email' => @user.email,
        #                                      'line_items' => [{
        #                                          'name' => @request.service.name,
        #                                          'description' => @request.service.description,
        #                                          'unit_price' => (@request.subtotal * 100).to_i,
        #                                          'quantity' => 1
        #                                      },
        #                                                       {
        #                                                           'name' => 'Comision gigbox',
        #                                                           'description' => 'Cobro por uso de plataforma',
        #                                                           'unit_price' => (@request.fee * 100).to_i,
        #                                                           'quantity' => 1
        #                                                       }]
        #                                  })
  
        @charge = Conekta::Order.create({
            :line_items => [{
                :name => @request.service.name,
                :unit_price => (@request.total * 100).to_i,
                :quantity => 1
            }], #line_items
            :currency => "MXN",
            :customer_info => {
                :customer_id =>  @request.user.conektaid
            }, #customer_info
            :charges => [{
                :payment_method => {
                    :payment_source_id => @request.token_card,
                    :type => "card"
                } # payment_method
            }],
        })                         
        return true

    rescue Conekta::ParameterValidationError => e
        @message_error = e
        return false
    rescue Conekta::ProcessingError => e
        @message_error = e
        return false
    rescue Conekta::Error => e
        return false
    end

    private

    def create_notification(request, message, user_from, user_to)
        user = User.find(user_to)

        email_content = "#{user_from.first_name} #{message} #{request.service.name}"
        MailNotification.send_mail_notification(user, email_content, user.email).deliver

        if Rails.env.production?
            MailNotification.send_mail_notification(user, email_content, 'gigbox@gmail.com').deliver
        end

        Notification.create(user_id: user_to.id,
                            notified_by_id: user_from.id,
                            request_service_id: request.id,
                            identifier: request.id,
                            type_notification: message,
                            read: false)
    end

    private

    def reply(request, _message, user_from, user_to)
        if Rails.env.production?
            user = User.find(user_to)
            boot_twilio
            if user.cellphone
                puts 'Envio de SMS solicitudes'
                sms_content = "#{user_from.first_name} esta interesado en contrarar tu servicio para el dia #{request.request_date.strftime('%d/%m/%Y')}. Ingresa a gigbox.mx para aceptar o rechazar."
                # sms_content = "#{user_from.first_name} #{message} #{request.service.name} ingresa a www.chambita.mx para aceptar o rechazar el servicio"
                from_number = "+52#{user.cellphone}"
                sms = @client.messages.create(
                    from: '+18326267620',
                    to: from_number,
                    body: sms_content
                )
            end
        end
    end

    private

    def boot_twilio
        account_sid = 'AC8d936b8298b25c1820624a58f0b67466'
        auth_token = 'ee5404c1235be5117b91bb2919f87249'
        @client = Twilio::REST::Client.new account_sid, auth_token
    end

    private

    def calculate_fee(price)
        fee = 0
        amex = 0.045
        visa_mastercard = 0.029

        if price <= 2000
            fee = price * 0.10
        elsif price >= 2001 && price <= 5000
            fee = price * 0.07
        elsif price >= 5001
            fee = price * 0.05
        else
            puts 'Error al calcular comision'
        end
        fee_IVA = (fee * 0.16)

        [fee, fee_IVA]
    end

    private

    def conekta_fee(subtotal)
        # La comision de conekta se calcula sin incluir el gasto de impuestos por comision de chambita
        fee_conekta = subtotal * 0.029

        fee_conekta + 2.5
    end
end
