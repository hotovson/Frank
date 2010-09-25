#!usr/bin/ruby

require 'rubygems'
require 'frank'
require 'haml'
require 'active_record'
require 'logger'

require 'models/user'
require 'models/role'
require 'models/preference'

class UserHandler < Frank

  #logout action  - nuke user from session, display login form and thank user
  get '/logout' do
    if is_logged_in?
      name = active_user.username
      log_user_out
      haml :login, :locals => { :message => t.u.logout_message(name), :name => "#{name}", :nav_tag => "login" }
    elsif is_remembered_user?
      name = active_username
      log_user_out
      haml :login, :locals => { :message => t.u.logout_completely(name), :name => "", :nav_tag => "login" }
    else
      haml :login, :locals => { :message => t.u.logout_error, :name => "", :nav_tag => "login" }
    end
  end

  # a user can delete themselves.
  post '/delete_self' do    
    if is_logged_in?
      @@log.warn("/delete_self called by #{active_user.username}.")
      if active_user.has_role?('admin')
        # admin users can not delete themselves.  remove the user from admin role before trying to delete them
        haml :'in/show_user', :locals => { :message => t.u.delete_me_error_admin, :user => active_user, :nav_tag => "profile" }
      else
        force = params['frankie_says_force_it']
        if force == 'true'
          # delete the user
          active_user.destroy
          log_user_out
          log_user_out # do it twice
          haml :register, :locals => { :message => t.u.delete_me_success,
            :name => "", :email => "", :nav_tag => "register" }
        else
          # throw up a warning screen.
          haml :'in/confirm_delete_self', :locals => { :message => t.u.delete_me_confirmation, :user => active_user, :nav_tag => "" }
        end
      end
    else
      @@log.error("/delete_self called but no-one was logged in. Check the UI and Navigation options in your templates.")
      haml :login, :locals => { :message => t.u.delete_me_error_login, :name => active_user, :nav_tag => "login" }
    end
  end

  # the show the current logged in user's details page
  get '/in/show_user' do
    login_required!
    haml :'in/show_user', :locals => { :message => t.u.profile_message, :user => active_user, :nav_tag => "profile" }
  end

  # the edit the current logged in user's details page
  get '/in/edit_user' do
    login_required!
    haml :'in/edit_user', :locals => { :message => t.u.profile_edit_message, :user => active_user, :nav_tag => "edit_profile" }
  end

  post '/in/editing_user' do
    login_required!
    user = active_user
    new_email = params['email']
    new_password = params['password']
    new_html_email_pref = params['html_email']
    
    user_changed = false
    error = false
    message = t.u.profile_edit_success
    
    old_html_email_pref = user.get_preference('HTML_EMAIL').value

    if old_html_email_pref != new_html_email_pref
      user.set_preference('HTML_EMAIL', new_html_email_pref)
      user_changed = true
    end
    # if the password is not '' then overwrite the password with the one supplied
    if new_password != ''
      user.password = new_password
      user_changed = true
    end
    # if the email is new then deactivate and send a confirmation message
    if new_email != user.email
      if User.email_exists?(new_email)
    	  notify_user_of_email_change_overlap_attempt!(new_email, user.username)
    	  message = t.u.profile_edit_error_email_clash(new_email) + t.u.profile_edit_error
    	  error = true
      else
        user.email = new_email
        user.validated = false
        send_email_update_confirmation_to(user)
        message = t.u.profile_edit_success_email_confirmation(new_email)
        user_changed = true
      end
    end
    if error
      haml :'in/edit_user', :locals => { :message => message, :user => active_user, :nav_tag => "edit_profile" }
  	elsif user_changed
      user.save!
      nuke_session!
      user.reload
      log_user_in(user) # puts the updated details back into the session.
      haml :'in/show_user', :locals => { :message => message, :user => active_user, :nav_tag => "profile" }
    else
      haml :'in/show_user', :locals => { :message => t.u.profile_edit_no_change, :user => active_user, :nav_tag => "profile" }
    end
  end

  # generic userland pages bounce to the logged in home page if logged in, or login page if not.
  get '/in/*' do
    login_required!
    haml :'in/index', :locals => { :message => t.u.hello_message, :user => active_user, :nav_tag => "home" }
  end
end
