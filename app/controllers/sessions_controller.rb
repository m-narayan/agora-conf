# -*- coding: utf-8 -*-
# Copyright 2008-2010 Universidad Politécnica de Madrid and Agora Systems S.A.
#
# This file is part of VCC (Virtual Conference Center).
#
# VCC is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# VCC is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with VCC.  If not, see <http://www.gnu.org/licenses/>.

# Require Station Controller
require_dependency "#{ Rails.root.to_s }/vendor/plugins/station/app/controllers/sessions_controller"

class SessionsController
  # Don't render Station layout, use application layout instead
  layout 'application_without_sidebar'

  #after_filter :update_user   #this is used to remember when did he logged in or out the last time and update his/her home

  skip_before_filter :verify_authenticity_token

  # render new.rhtml
  def new
    if logged_in?
      flash[:error] = t('session.error.exist')
      redirect_to root_path
      return
    end

    store_location(params[:return_to])

    # See ActionController::Sessions#authentication_methods_chain
    authentication_methods_chain(:new)

    respond_to do |format|
      if request.xhr?
        format.js {
          render :partial => "sessions/login"
        }
      end
      format.html
      format.m
    end
  end

  def create
    if Site.current.site_agora_login
      response=socket_login
      if response["user_email"]
        user=User.find_by_email(response["user_email"])
        if user == nil
          user=User.new(:login=>params[:login],:email => response["user_email"],:password=>params[:password],:password_confirmation =>params[:password],:activated_at=>Time.now)
          title=""
          full_name=response["user_name"]
          pos=full_name.index(".")
          if pos != nil
            title = full_name[0,pos].downcase
            full_name = full_name[pos+2,full_name.length]
            full_name=full_name.gsub(",","")
          end
          user._full_name = full_name
          user._prefix_key="title_formal.#{title}"
          user.save!
        else
          user.update_attributes(:email => response["user_email"],:password=>params[:password],:password_confirmation =>params[:password])
          #user.profile.update_attributes(:full_name => response["full_name"])
        end
      end
    end

    if authentication_methods_chain(:create)
      respond_to do |format|
        format.html {
          redirect_back_or_default(after_create_path)
        }
        format.js
      end unless performed?
    else
      respond_to do |format|
        format.html {
          flash[:error] ||= t(:invalid_credentials)
          render(:action => "new")
        }
        format.js
      end unless performed?
    end
  end

  private

  def after_create_path
    if current_user.superuser == true && Site.current.new_record?
      flash[:notice] = t('session.error.fill')
      edit_site_path
    elsif params[:url]
      params[:url]
    else
      session[:return_to] ? session[:return_to] : home_path
    end
  end

  def after_destroy_path
    root_path
  end

  def update_user
    current_user.touch
  end

  def application_layout
    (request.format.to_sym == :m)? 'mobile.html' : 'application'
  end

  def socket_login
    hostname = Site.current.site_agora_login_server
    port = Site.current.site_agora_login_port
    begin
      socket = TCPSocket.open(hostname, port)
      request={:username => params[:login],:password =>params[:password]}
      socket.print request.to_json
      socket.close_write
      response = JSON.parse socket.gets
      socket.close
      response
    rescue Exception => myException
      puts "#{myException}"
    end
  end
end
