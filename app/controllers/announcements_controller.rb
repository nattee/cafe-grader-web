class AnnouncementsController < ApplicationController

  before_action :set_announcement, only: [:show, :edit, :create, :edit, :destroy,
                                          :toggle_published, :toggle_front]

  before_action :admin_authorization
  before_action :stimulus_controller

  # GET /announcements
  # GET /announcements.xml
  def index
    @announcements = Announcement.order(created_at: :desc)

    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @announcements }
    end
  end

  # GET /announcements/1
  # GET /announcements/1.xml
  def show

    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @announcement }
    end
  end

  # GET /announcements/new
  # GET /announcements/new.xml
  def new
    @announcement = Announcement.new

    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @announcement }
    end
  end

  # GET /announcements/1/edit
  def edit
  end

  # POST /announcements
  # POST /announcements.xml
  def create
    respond_to do |format|
      if @announcement.save
        flash[:notice] = 'Announcement was successfully created.'
        format.html { redirect_to(@announcement) }
        format.xml  { render :xml => @announcement, :status => :created, :location => @announcement }
      else
        format.html { render :action => "new" }
        format.xml  { render :xml => @announcement.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /announcements/1
  # PUT /announcements/1.xml
  def update
    respond_to do |format|
      if @announcement.update(announcement_params)
        flash[:notice] = 'Announcement was successfully updated.'
        format.html { redirect_to(@announcement) }
        format.js   {}
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.js   {}
        format.xml  { render :xml => @announcement.errors, :status => :unprocessable_entity }
      end
    end
  end

  def toggle_published
    @announcement.update( published:  !@announcement.published? )
    @toast = {title: "Annnouncement",body: "published updated"}
    render 'toggle'
  end

  def toggle_front
    @announcement.update( frontpage:  !@announcement.frontpage? )
    @toast = {title: "Announcement",body: "front updated"}
    render 'toggle'
  end

  # DELETE /announcements/1
  # DELETE /announcements/1.xml
  def destroy
    @announcement.destroy

    respond_to do |format|
      format.html { redirect_to(announcements_url) }
      format.xml  { head :ok }
    end
  end

  private
    def set_announcement
      @announcement = Announcement.find(params[:id])
    end

    def announcement_params
      params.require(:announcement).permit(:author, :body, :published, :frontpage, :contest_only, :title, :on_nav_bar, :file)
    end

    def stimulus_controller
      @stimulus_controller = 'announcement'
    end
end
