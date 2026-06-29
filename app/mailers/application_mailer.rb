class ApplicationMailer < ActionMailer::Base
  default from: ENV.fetch("MAILER_SENDER", "no-reply@dofi.gov.bn")
  layout "mailer"
end
