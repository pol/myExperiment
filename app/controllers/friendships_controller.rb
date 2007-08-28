##
##
## myExperiment - a social network for scientists
##
## Copyright (C) 2007 University of Manchester/University of Southampton
##
## This program is free software; you can redistribute it and/or modify
## it under the terms of the GNU Affero General Public License
## as published by the Free Software Foundation; either version 3 of the
## License, or (at your option) any later version.
##
## This program is distributed in the hope that it will be useful,
## but WITHOUT ANY WARRANTY; without even the implied warranty of
## MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
## GNU Affero General Public License for more details.
##
## You should have received a copy of the GNU Affero General Public License
## along with this program; if not, see http://www.gnu.org/licenses
## or write to the Free Software Foundation,Inc., 51 Franklin Street,
## Fifth Floor, Boston, MA 02110-1301  USA
##
##

class FriendshipsController < ApplicationController
  before_filter :login_required, :except => [:index, :show]
  
  before_filter :find_friendships, :only => [:index]
  before_filter :find_friendship, :only => [:show]
  before_filter :find_friendship_auth, :only => [:accept, :edit, :update, :destroy]
  
  # GET /users/1/friendships/1/accept
  # GET /users/1/friendships/1/accept.xml
  # GET /friendships/1/accept
  # GET /friendships/1/accept.xml
  def accept
    respond_to do |format|
      if @friendship.accept!
        flash[:notice] = 'Friendship was successfully accepted.'
        format.html { redirect_to friendships_url(current_user.id) }
        format.xml  { head :ok }
      else
        error("Friendship already accepted", "already accepted")
      end
    end
  end
  
  # GET /users/1/friendships
  # GET /users/1/friendships.xml
  # GET /friendships
  # GET /friendships.xml
  def index
    respond_to do |format|
      format.html # index.rhtml
      format.xml  { render :xml => @friendships.to_xml }
    end
  end

  # GET /users/1/friendships/1
  # GET /users/1/friendships/1.xml
  # GET /friendships/1
  # GET /friendships/1.xml
  def show
    respond_to do |format|
      format.html # show.rhtml
      format.xml  { render :xml => @friendship.to_xml }
    end
  end

  # GET users/1/friendships/new
  # GET /friendships/new
  def new
    unless params[:user_id] and params[:user_id].to_i != current_user.id.to_i
      @friendship = Friendship.new(:user_id => current_user.id)
    else
      @friendship = Friendship.new(:user_id => current_user.id, :friend_id => params[:user_id])
    end
  end

  # GET /users/1/friendships/1;edit
  # GET /friendships/1;edit
  def edit
    
  end

  # POST /users/1/friendships
  # POST /users/1/friendships.xml
  # POST /friendships
  # POST /friendships.xml
  def create
    if (@friendship = Friendship.new(params[:friendship]) unless Friendship.find_by_user_id_and_friend_id(params[:friendship][:user_id], params[:friendship][:friend_id]))
      # set initial datetime
      @friendship.accepted_at = nil

      respond_to do |format|
        if @friendship.save
          flash[:notice] = 'Friendship was successfully requested.'
          format.html { redirect_to friendship_url(@friendship.friend_id, @friendship) }
          format.xml  { head :created, :location => friendship_url(@friendship.friend_id, @friendship) }
        else
          format.html { render :action => "new" }
          format.xml  { render :xml => @friendship.errors.to_xml }
        end
      end
    else
      error("Friendship not created (already exists)", "not created, already exists")
    end
  end

  # PUT /users/1/friendships/1
  # PUT /users/1/friendships/1.xml
  # PUT /friendships/1
  # PUT /friendships/1.xml
  def update
    # no spoofing of acceptance
    params[:friendship].delete('accepted_at') if params[:friendship][:accepted_at]
    
    respond_to do |format|
      if @friendship.update_attributes(params[:friendship])
        flash[:notice] = 'Friendship was successfully updated.'
        format.html { redirect_to friendship_url(@friendship.user_id, @friendship) }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @friendship.errors.to_xml }
      end
    end
  end

  # DELETE users/1/friendships/1
  # DELETE users/1/friendships/1.xml
  # DELETE /friendships/1
  # DELETE /friendships/1.xml
  def destroy
    friend_id = @friendship.friend_id
    
    @friendship.destroy

    respond_to do |format|
      format.html { redirect_to friendships_url(friend_id) }
      format.xml  { head :ok }
    end
  end
  
protected

  def find_friendships
    if params[:user_id]
      begin
        @user = User.find(params[:user_id])
    
        @friendships = @user.friendships
      rescue ActiveRecord::RecordNotFound
        error("User not found", "is invalid", :user_id)
      end
    else
      @friendships = Friendship.find(:all, :order => "created_at DESC")
    end
  end

  def find_friendship
    if params[:user_id]
      begin
        @user = User.find(params[:user_id])
    
        begin
          @friendship = Friendship.find(params[:id], :conditions => ["friend_id = ?", @user.id])
        rescue ActiveRecord::RecordNotFound
          error("Friendship not found", "is invalid")
        end
      rescue ActiveRecord::RecordNotFound
        error("User not found", "is invalid", :user_id)
      end
    else
      begin
        @friendship = Friendship.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        error("Friendship not found", "is invalid")
      end
    end
  end
  
  def find_friendship_auth
    begin
      if action_name.to_s == "show"
        @friendship = Friendship.find(params[:id], :conditions => ["friend_id = ? or user_id = ?", current_user.id, current_user.id])
      else
        @friendship = Friendship.find(params[:id], :conditions => ["friend_id = ?", current_user.id])
      end
    rescue ActiveRecord::RecordNotFound
      error("Friendship not found (id not authorized)", "is invalid (not named)")
    end
  end
  
private
  
  def error(notice, message)
    flash[:notice] = notice
    (err = Friendship.new.errors).add(:id, message)
    
    respond_to do |format|
      format.html { redirect_to friendships_url(current_user.id) }
      format.xml { render :xml => err.to_xml }
    end
  end
end
