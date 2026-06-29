class UserMailer < ApplicationMailer
  def reset_password_instructions(user, token)
    @user = user
    @reset_password_url = "#{frontend_url}/reset-password?token=#{token}"

    I18n.with_locale(user.preferred_locale) do
      mail(to: @user.email, subject: I18n.t("user_mailer.reset_password_instructions.subject"))
    end
  end

  private

  def frontend_url
    ENV.fetch("FRONTEND_URL", "http://localhost:5173")
  end
end
