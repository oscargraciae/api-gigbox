class PurchaseDetail < ApplicationMailer
  default :from => 'Gigbox <hello@gigbox.mx>'

  layout false
  # send a signup email to the user, pass in the user object that contains the user's email address
  def send_purchase_detail(user, request, service, supplier)

    neto = service.price + request.fee

    headers "X-SMTPAPI" => {
      "sub": {
        "%name%" => [user.first_name],
        "%service_name%" => [service.name],
        "%service_date%" => [request.request_date],
        "%service_time%" => [request.request_time],
        "%service_supplier%" => [supplier.first_name],
        "%service_bruto%" => [request.subtotal],
        "%service_comision%" => [request.fee],
        "%service_neto%" => [request.total]
      },
      "filters": {
        "templates": {
          "settings": {
            "enable": 1,
            "template_id": '22df6bca-f8c3-4e30-a097-34c7c0664c3f'
          }
        }
      }
    }.to_json

    mail( :to => user.email,:subject => 'Tu servicio fue solicitado satisfactoriamente' )
  end
end
