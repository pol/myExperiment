class SessionController < ApplicationController
  def create
    if using_open_id?
      open_id_authentication
    else
      password_authentication(params[:username], params[:password])
    end
  end
  
  def destroy
    self.current_user.forget_me if logged_in?
    cookies.delete :auth_token
    reset_session
    flash[:notice] = "You have been logged out. Thank you for using myExperiment!"
    redirect_back_or_default(url_for(:controller => "contributions"))
  end
  
  # handle the openid server response
  def complete
    response = consumer.complete(params)
    
    case response.status
    when OpenID::SUCCESS

      @user = User.find_first(["openid_url = ?", response.identity_url])
      
      # create user object if one does not exist
      if @user.nil?
        @user = User.new(:openid_url => response.identity_url, :name => "Joe Bloggs BSc (change me)")
        @user.save
      end

      # storing both the openid_url and user id in the session for for quick
      # access to both bits of information.  Change as needed.
      #session[:user_id] = @user.id
      self.current_user = @user

      flash[:notice] = "Logged in as #{@user.name}"
       
      successful_login(@user)
      return

    when OpenID::FAILURE
      if response.identity_url
        flash[:notice] = "Verification of #{CGI::escape(response.identity_url)} failed."

      else
        flash[:notice] = 'Verification failed.'
      end

    when OpenID::CANCEL
      flash[:notice] = 'Verification cancelled.'

    else
      flash[:notice] = 'Unknown response from OpenID server.'
    end
  
    failed_login(flash[:notice])
  end

  protected
  
    def password_authentication(login, password)
      self.current_user = User.authenticate(login, password)
      if logged_in?
        if params[:remember_me] == "1"
          self.current_user.remember_me
          cookies[:auth_token] = { :value => self.current_user.remember_token , :expires => self.current_user.remember_token_expires_at }
        end
        successful_login(self.current_user)
      else
        failed_login('Invalid login or password')
      end
    end

    def open_id_authentication
      openid_url = params[:openid_url]
      
      if request.post?
        request = consumer.begin(openid_url)
        
        case request.status
        when OpenID::SUCCESS
          return_to = url_for(:action=> 'complete')
          trust_root = url_for(:controller=>'')
          
          url = request.redirect_url(trust_root, return_to)
          redirect_to(url)
          return
          
        when OpenID::FAILURE
          escaped_url = CGI::escape(openid_url)
          flash[:notice] = "Could not find OpenID server for #{escaped_url}"
        else
          flash[:notice] = "An unknown error occured."
        end
      end
    end

    # registration is a hash containing the valid sreg keys given above
    # use this to map them to fields of your user model
    def assign_registration_attributes!(registration)
      { :username => 'name' }.each do |model_attribute, registration_attribute|
        unless registration[registration_attribute].blank?
          @user.send("#{model_attribute}=", registration[registration_attribute])
        end
      end
      @user.save!
    end

  private
  
    def successful_login(user)
      redirect_back_or_default(user_path(user))
      flash[:notice] = "Logged in successfully. Welcome to myExperiment!"
    end

    def failed_login(message)
      flash.now[:error] = message
      render :action => 'new'
    end
    
  # Get the OpenID::Consumer object.
  def consumer
    # create the OpenID store for storing associations and nonces,
    # putting it in your app's db directory
    store_dir = Pathname.new(RAILS_ROOT).join('db').join('openid-store')
    store = OpenID::FilesystemStore.new(store_dir)

    return OpenID::Consumer.new(session, store)
  end
end
