# encoding: utf-8
#--
#   Copyright (C) 2012 Gitorious AS
#   Copyright (C) 2009 Nokia Corporation and/or its subsidiary(-ies)
#   Copyright (C) 2008 Johan Sørensen <johan@johansorensen.com>
#   Copyright (C) 2008 David Chelimsky <dchelimsky@gmail.com>
#   Copyright (C) 2008 Tim Dysinger <tim@dysinger.net>
#   Copyright (C) 2008 Tor Arne Vestbø <tavestbo@trolltech.com>
#   Copyright (C) 2009 Fabio Akita <fabio.akita@gmail.com>
#
#   This program is free software: you can redistribute it and/or modify
#   it under the terms of the GNU Affero General Public License as published by
#   the Free Software Foundation, either version 3 of the License, or
#   (at your option) any later version.
#
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU Affero General Public License for more details.
#
#   You should have received a copy of the GNU Affero General Public License
#   along with this program.  If not, see <http://www.gnu.org/licenses/>.
#++

class Mailer < ActionMailer::Base
  include ActionView::Helpers::SanitizeHelper
  extend ActionView::Helpers::SanitizeHelper::ClassMethods
  include ActionController::UrlWriter

  default(:from => lambda { GitoriousConfig["sender_email_address"] ||
            "Gitorious <no-reply@#{GitoriousConfig['gitorious_host']}>" })

  def signup_notification(user)
    @user = user
    @url = url_for({
      :controller => "users",
      :action => "activate",
      :activation_code => user.activation_code
    })
    mail(:to => format_address(user),
         :subject => prefixed_subject(I18n.t("mailer.subject")))
  end

  def activation(user)
    @user = user
    mail(:to => format_address(user),
         :subject => prefixed_subject(I18n.t("mailer.activated")))
  end

  def notification_copy(recipient, sender, subject, body, notifiable, message_id)
    @url = url_for({
      :controller => "messages",
      :action => "show",
      :id => message_id,
      :host => GitoriousConfig["gitorious_host"]
    })
    @body = sanitize(body)
    @recipient = recipient.title.to_s
    @sender = sender.title.to_s

    if "1.9".respond_to?(:force_encoding)
      @recipient = @recipient.force_encoding("utf-8")
      @sender = @sender.force_encoding("utf-8")
    end

    @notifiable_url = build_notifiable_url(notifiable) if notifiable
    mail(:to => format_address(recipient),
         :from => format_address(sender),
         :subject => "New message: " + sanitize(subject))
  end

  def forgotten_password(user, pw_key)
    @user = user
    @url = reset_password_url(pw_key, :protocol => GitoriousConfig["scheme"])
    mail(:to => format_address(user),
         :subject => prefixed_subject(I18n.t("mailer.new_password")))
  end

  def new_email_alias(email)
    @email = email
    @url = confirm_user_alias_url(email.user, email.confirmation_code)
    mail(:to => email.address,
         :subject => prefixed_subject("Please confirm this email alias"))
  end

  def message_processor_error(processor, err, message_body = nil)
    @error = err
    @message = message_body
    @processor = processor
    subject = prefixed_subject("fail in #{processor.class.name}", "Processor")
    mail(:to => GitoriousConfig["exception_notification_emails"],
         :subject => subject)
  end

  def favorite_notification(user, notification_body)
    @user = user
    @notification_body = notification_body
    mail(:to => format_address(user),
         :subject => prefixed_subject("Activity: #{notification_body[0,35]}..."))
  end

  protected
  def build_notifiable_url(a_notifiable)
    case a_notifiable
    when MergeRequest
      target = a_notifiable.target_repository
      return project_repository_merge_request_url(target.project, target, a_notifiable)
    when Membership
      return group_path(a_notifiable.group)
    end
  end

  def format_address(user)
    "#{user.fullname} <#{user.email}>"
  end

  def prefixed_subject(subject, prefix = nil)
    prefix = "#{GitoriousConfig['site_name']} #{prefix}".strip
    "[#{prefix}] #{subject}"
  end
end
