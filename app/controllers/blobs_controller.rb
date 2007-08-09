class BlobsController < ApplicationController
  # GET /blobs/1;download
  def download
    @blob = Blob.find(params[:id])
    
    if @blob.authorized?("download", (logged_in? ? current_user : nil))
      send_data(@blob.data, :filename => @blob.local_name, :type => @blob.content_type)
    else
      flash[:notice] = "Not authorized to download #{@blob.local_name}"
      redirect_to 'index'
    end
    
    #send_file("#{RAILS_ROOT}/#{controller_name}/#{@blob.contributor_type.downcase.pluralize}/#{@blob.contributor_id}/#{@blob.local_name}", :filename => @blob.local_name, :type => @blob.content_type)
  end
  
  # GET /blobs
  # GET /blobs.xml
  def index
    @blobs = Blob.find(:all)

    respond_to do |format|
      format.html # index.rhtml
      format.xml  { render :xml => @blobs.to_xml }
    end
  end

  # GET /blobs/1
  # GET /blobs/1.xml
  def show
    @blob = Blob.find(params[:id])

    respond_to do |format|
      format.html # show.rhtml
      format.xml  { render :xml => @blob.to_xml }
    end
  end

  # GET /blobs/new
  def new
    @blob = Blob.new
  end

  # GET /blobs/1;edit
  def edit
    @blob = Blob.find(params[:id])
  end

  # POST /blobs
  # POST /blobs.xml
  def create
    params[:blob][:local_name] = sanitize_filename(params[:blob][:data].original_filename)
    params[:blob][:content_type] = params[:blob][:data].content_type
    params[:blob][:data] = params[:blob][:data].read
    
    # params[:blob][:data].rewind
    # File.open("#{RAILS_ROOT}/uploaded_#{controller_name}/#{params[:blob][:contributor_type].downcase.pluralize}/#{params[:blob][:contributor_id]}/#{params[:blob][:local_name]}", "wb") do |f|  
    #   f.write(params[:blob][:data].read)
    # end
    
    # params[:blob].delete('data')
    
    @blob = Blob.new(params[:blob])

    respond_to do |format|
      if @blob.save
        flash[:notice] = 'Blob was successfully created.'
        format.html { redirect_to blob_url(@blob) }
        format.xml  { head :created, :location => blob_url(@blob) }
      else
        format.html { render :action => "new" }
        format.xml  { render :xml => @blob.errors.to_xml }
      end
    end
  end

  # PUT /blobs/1
  # PUT /blobs/1.xml
  def update
    @blob = Blob.find(params[:id])

    respond_to do |format|
      if @blob.update_attributes(params[:blob])
        flash[:notice] = 'Blob was successfully updated.'
        format.html { redirect_to blob_url(@blob) }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @blob.errors.to_xml }
      end
    end
  end

  # DELETE /blobs/1
  # DELETE /blobs/1.xml
  def destroy
    @blob = Blob.find(params[:id])
    @blob.destroy

    respond_to do |format|
      format.html { redirect_to blobs_url }
      format.xml  { head :ok }
    end
  end
  
private

  # http://manuals.rubyonrails.com/read/chapter/78
  def sanitize_filename(file_name)
    # get only the filename, not the whole path (from IE)
    just_filename = File.basename(file_name) 
    # replace all non-alphanumeric, underscore or periods with underscores
    just_filename.gsub(/[^\w\.\-]/,'_') 
  end
end
