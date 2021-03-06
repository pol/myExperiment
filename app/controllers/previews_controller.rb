# myExperiment: app/controllers/previews_controller.rb
#
# Copyright (c) 2011 University of Manchester and the University of Southampton.
# See license.txt for details.

class PreviewsController < ApplicationController

  before_filter :find_context

  def show

    auth = request.env["HTTP_AUTHORIZATION"]
    user = current_user

    if auth and auth.starts_with?("Basic ")
      credentials = Base64.decode64(auth.sub(/^Basic /, '')).split(':')
      user = User.authenticate(credentials[0], credentials[1])

      if user.nil?
        render :nothing => true, :status => "401 Unauthorized"
        response.headers['WWW-Authenticate'] = "Basic realm=\"#{Conf.sitename} REST API\""
        return
      end
    end

    if @context.preview.nil?
      render :nothing => true, :status => "404 Not Found"
      return
    end

    if @context.respond_to?("versioned_resource")
      auth_object = @context.versioned_resource
    else
      auth_object = @context
    end

    if Authorization.check(:action => 'view', :object => auth_object, :user => user) == false
      render :nothing => true, :status => "401 Unauthorized"
      response.headers['WWW-Authenticate'] = "Basic realm=\"#{Conf.sitename} REST API\""
      return
    end

    type = params[:id]

    case type

      when 'full';   name = 'full';   source = 'image'; size = nil; mime_type = 'image/jpeg'
      when 'medium'; name = 'medium'; source = 'image'; size = 500; mime_type = 'image/jpeg'
      when 'thumb';  name = 'thumb';  source = 'image'; size = 100; mime_type = 'image/jpeg'
      when 'svg';    name = 'svg';    source = 'svg';   size = nil; mime_type = 'image/svg+xml'
      else
        render(:inline => 'Bad preview type', :status => "400 Bad Request")
        return
    end

    file_name = @context.preview.file_name(type)

    send_cached_data(file_name, :type => mime_type, :disposition => 'inline') {

      case source
        when 'image'; content_blob = @context.preview.image_blob
        when 'svg';   content_blob = @context.preview.svg_blob
      end

      data = content_blob.data

      if size

        img = Magick::Image.from_blob(data).first
        img = img.change_geometry("#{size}x#{size}>") do |c, r, i| i.resize(c, r) end

        result = Magick::Image.new(img.columns, img.rows)
        result = result.composite(img, 0, 0, Magick::OverCompositeOp)
        result.format = "jpg"

        data = result.to_blob
      end

      data
    }
  end

  private

  def find_context
    @context = extract_resource_context(params)
    return false unless @context

    @context = @context.find_version(params[:version]) if params[:version]
    return false unless @context
  end

end

