class OutgoingEmail
  attr_reader :email

  def initialize(email)
    @email = email
  end

  def send
    # TODO If no emails are sent out don't open connection to smtp server
    Net::SMTP.start(Rails.configuration.postfix_smtp_host, Rails.configuration.postfix_smtp_port) do |smtp|
      email.deliveries.each do |delivery|
        if delivery.forward?
          # TODO: Optimise so that if data is the same for multiple recipients then they
          # are sent in one go
          filtered = DeliveryFilter.new(delivery)
          response = smtp.send_message(filtered.data, filtered.from, [filtered.to])
          delivery.update_attributes(
            postfix_queue_id: OutgoingEmail.extract_postfix_queue_id_from_smtp_message(response.message),
            sent: true)
        end
      end
    end
  end

  # When a message is sent via the Postfix MTA it returns the queue id
  # in the SMTP message. Extract this
  def self.extract_postfix_queue_id_from_smtp_message(message)
    m = message.match(/250 2.0.0 Ok: queued as (\w+)/)
    m[1] if m
  end
end

class DeliveryFilter
  attr_reader :delivery

  def initialize(delivery)
    @delivery = delivery
  end

  def from
    delivery.from
  end

  def to
    delivery.to
  end

  def data
    delivery.data
  end
end
