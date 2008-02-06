# myExperiment: app/controllers/application.rb
#
# Copyright (c) 2007 University of Manchester and the University of Southampton.
# See license.txt for details.

# Filters added to this controller apply to all controllers in the application.
# Likewise, all the methods added will be available for all controllers.

class ApplicationController < ActionController::Base
  
  WhiteListHelper.tags.merge %w(table tr td th div span)
  
  include Sitealizer
  before_filter :use_sitealizer

  include AuthenticatedSystem
  before_filter :login_from_cookie
  
  helper ForumsHelper

  # Pick a unique cookie name to distinguish our session data from others'
  session :session_key => '_m2_session_id'
  
  def base_host
    request.host_with_port
  end
  
  def can_manage_pages?
    return admin?  # from authenticated_system
  end
  
  # Safe HTML - http://www.anyexample.com/webdev/rails/how_to_allow_some_safe_html_in_rails_projects.xml
  # Note: should only be used for text that doesn't need updating later.
  def ae_some_html(s)
    return '' if s.nil?    
    
    # converting newlines
    s.gsub!(/\r\n?/, "\n")
 
    # escaping HTML to entities
    s = s.to_s.gsub('&', '&amp;').gsub('<', '&lt;').gsub('>', '&gt;')
 
    # blockquote tag support
    s.gsub!(/\n?&lt;blockquote&gt;\n*(.+?)\n*&lt;\/blockquote&gt;/im, "<blockquote>\\1</blockquote>")
 
    # other tags: b, i, em, strong, u
    %w(b i em strong u).each { |x|
         s.gsub!(Regexp.new('&lt;(' + x + ')&gt;(.+?)&lt;/('+x+')&gt;',
                 Regexp::MULTILINE|Regexp::IGNORECASE), 
                 "<\\1>\\2</\\1>")
        }
 
    # A tag support
    # href="" attribute auto-adds http://
    s = s.gsub(/&lt;a.+?href\s*=\s*['"](.+?)["'].*?&gt;(.+?)&lt;\/a&gt;/im) { |x|
            '<a href="' + ($1.index('://') ? $1 : 'http://'+$1) + "\">" + $2 + "</a>"
          }
 
    # replacing newlines to <br> ans <p> tags
    # wrapping text into paragraph
    s = "<p>" + s.gsub(/\n\n+/, "</p>\n\n<p>").
            gsub(/([^\n]\n)(?=[^\n])/, '\1<br />') + "</p>"
 
    s      
  end
  
  # This method takes a comma seperated list of tags (where multiple words don't need to be in quote marks)
  # and formats it into a new comma seperated list where multiple words ARE in quote marks.
  # (Note: it will actually put quote marks around all the words and then out commas).
  # eg: 
  #    this, is a, tag
  #        becomes:
  #    "this","is a","tag"
  #
  # This is so we can map the tags entered in by users to the format required by the act_as_taggable_redux gem.
  def convert_tags_to_gem_format(tags_string)
    list = parse_comma_seperated_string(tags_string)
    converted = '' 
    
    list.each do |s|
      converted = converted + '"' + s.strip + '",'
    end
    
    return converted
  end
  
  helper_method :ae_some_html
  
  # This method converts a comma seperated string of values into a collection of those values.
  # Note: currently does not cater for values in quotation marks and does not remove empty values
  # (although it does ignore a trailing comma)
  def parse_comma_seperated_string(s)
    list = s.split(',')
  end

  def update_policy(contributable, params)

    # BEGIN validation and initialisation
    
    return if params[:sharing].nil? or params[:sharing][:class_id].blank?
    
    params[:updating][:class_id] = "6" if params[:updating].nil? or params[:updating][:class_id].blank?

    sharing_class  = params[:sharing][:class_id]
    updating_class = params[:updating][:class_id]
    
    # Check allowed sharing_class values
    return unless [ "0", "1", "2", "3", "4", "7" ].include? sharing_class
    
    # Check allowed updating_class values
    return unless [ "0", "1", "5", "6" ].include? updating_class
    
    view_protected     = false
    view_public        = false
    download_protected = false
    download_public    = false
    edit_protected     = false
    edit_public        = false
    
    # BEGIN initialisation and validation

    case sharing_class
      when "0"
        view_public        = "1"
        download_public    = "1"
      when "1"
        view_public        = "1"
        download_protected = "1"
      when "2"
        view_public        = "1"
      when "3"
        view_protected     = "1"
        download_protected = "1"          
      when "4"
        view_protected     = "1"
    end

    case updating_class
      when "0"
        edit_protected = true if view_protected == "1" and download_protected == "1"
        edit_public    = true if view_public    == "1" and download_public    == "1"
      when "1"
        edit_protected = true
    end

    unless contributable.contribution.policy
      policy = Policy.new(:name => 'auto',
          :contributor_type => 'User', :contributor_id => current_user.id,
          :view_protected     => view_protected,
          :view_public        => view_public,
          :download_protected => download_protected,
          :download_public    => download_public,
          :edit_protected     => edit_protected,
          :edit_public        => edit_public,
          :share_mode         => sharing_class,
          :update_mode        => updating_class)
      contributable.contribution.policy = policy
      contributable.contribution.save
    else
       policy = contributable.contribution.policy
       policy.view_protected = view_protected,
       policy.view_public = view_public,
       policy.download_protected = download_protected,
       policy.download_public = download_public,
       policy.edit_protected = edit_protected,
       policy.edit_public = edit_public,
       policy.share_mode = sharing_class,
       policy.update_mode = updating_class
       policy.save
    end

    # Process 'update' permissions for "Some of my Friends"

    # Delete old User permissions
    policy.permissions.each do |p|
      if p.contributor_type == 'User'
        p.destroy
      end
    end
    
    # Now create new User permissions, if required
    if updating_class == "5"
      params[:updating_somefriends].each do |f|
        Permission.new(:policy => policy,
            :contributor => (User.find f[1].to_i),
            :view => 1, :download => 1, :edit => 1).save
      end
    end
    
    # Process explicit Group permissions now
    if params[:group_sharing]
      
      # First delete any Permission objects that don't have a checked entry in the form
      policy.permissions.each do |p|
        params[:group_sharing].each do |n|
          unless n[1][:id]
            if p.contributor_type == 'Network' and p.contributor_id == n[0].to_i
              p.destroy
            end
          end
        end
      end
    
      # Now create or update Permissions
      params[:group_sharing].each do |n|
        
        # Note: n[1] is used because n is an array and n[1] returns it's value (which in turn is a hash)
        if n[1][:id]
          
          n_id = n[1][:id].to_i
          level = n[1][:level]
          
          unless (perm = Permission.find(:first, :conditions => ["policy_id = ? AND contributor_type = ? AND contributor_id = ?", policy.id, 'Network', n_id]))
            # Only create new Permission if it doesn't already exist
            p = Permission.new(:policy => policy, :contributor => (Network.find(n_id)))
            p.set_level!(level) if level
          else
            # Update the 'level' on the existing permission
            perm.set_level!(level) if level
          end
          
        else
          
          n_id = n[1][:id].to_i
          
          # Delete permission if it exists (because this one is unchecked)
          if (perm = Permission.find(:first, :conditions => ["policy_id = ? AND contributor_type = ? AND contributor_id = ?", policy.id, 'Network', n_id]))
            perm.destroy
          end
          
        end
      
      end
    end

    puts "------ Workflow create summary ------------------------------------"
    puts "current_user   = #{current_user.id}"
    puts "updating_class = #{updating_class}"
    puts "sharing_class  = #{sharing_class}"
    puts "policy         = #{policy}"
    puts "group_sharing  = #{params[:group_sharing]}"
    puts "-------------------------------------------------------------------"

  end

  def determine_sharing_mode(contributable)

    policy = contributable.contribution.policy

    return policy.share_mode if !policy.share_mode.nil?

    v_pub  = policy.view_public;
    v_prot = policy.view_protected;
    d_pub  = policy.download_public;
    d_prot = policy.download_protected;
    e_pub  = policy.edit_public;
    e_prot = policy.edit_protected;

    if (policy.permissions.length == 0)

      if ((v_pub  == true ) && (v_prot == false) && (d_pub  == true ) && (d_prot == false))
        return 0
      end

      if ((v_pub  == true ) && (v_prot == false) && (d_pub  == false) && (d_prot == true ))
        return 1;
      end

      if ((v_pub  == true ) && (v_prot == false) && (d_pub  == false) && (d_prot == false))
        return 2;
      end

      if ((v_pub  == false) && (v_prot == true ) && (d_pub  == false) && (d_prot == true ))
        return 3;
      end

      if ((v_pub  == false) && (v_prot == true ) && (d_pub  == false) && (d_prot == false))
        return 4;
      end

      if ((v_pub  == false) && (v_prot == false) && (d_pub  == false) && (d_prot == false))
        return 7;
      end

    end

    return 8

  end

  def determine_updating_mode(contributable)

    policy = contributable.contribution.policy

    return policy.update_mode if !policy.update_mode.nil?

    v_pub  = policy.view_public;
    v_prot = policy.view_protected;
    d_pub  = policy.download_public;
    d_prot = policy.download_protected;
    e_pub  = policy.edit_public;
    e_prot = policy.edit_protected;

    perms  = policy.permissions.select do |p| p.edit end

    if (perms.empty?)

      # mode 1? only friends and network members can edit
   
      if (e_pub == false and e_prot == true)
        return 1
      end
   
      # mode 6? noone else
   
      if (e_pub == false and e_prot == false)
        return 6
      end

    else

      # mode 0? same as those that can view or download

      if (e_pub == v_pub or d_pub)
        if (e_prot == v_prot or d_prot)
          if (perms.collect do |p| p.edit != p.view or p.download end).empty?
            return 0;
          end
        end
      end

      contributor = User.find(contributable.contributor_id)

      contributors_friends  = contributor.friends.map do |f| f.id end
      contributors_networks = (contributor.networks + contributor.networks_owned).map do |n| n.id end

      my_networks    = []
      other_networks = []
      my_friends     = []
      other_users    = []

      puts "contributors_networks = #{contributors_networks.map do |n| n.id end}"

      perms.each do |p|
        puts "contributor_id = #{p.contributor_id}"
        case
          when 'Network'

            if contributors_networks.index(p.contributor_id).nil?
              other_networks.push p
            else
              my_networks.push p
            end

          when 'User'

            if contributors_friends.index(p.contributor_id).nil?
              other_users.push p
            else
              friends.push p
            end

        end
      end

      puts "my_networks    = #{my_networks.length}"
      puts "other_networks = #{other_networks.length}"
      puts "my_friends     = #{my_friends.length}"
      puts "other_users    = #{other_users.length}"

      if (other_networks.empty? and other_users.empty?)

        # mode 5? some of my friends?

        if (my_networks.empty? and !my_friends.empty?)
          return 5
        end

      end
    end

    # custom

    return 7

  end

  def refresh_tags(taggable, tags, tagger)

    old_tags = taggable.tags.map do |tag| tag.name end
    new_tags = tags.split(",").map do |t| t.strip end

    puts "#DEBUG: old_tags = #{old_tags}"
    puts "#DEBUG: new_tags = #{new_tags}"

    # remove tags

    taggable.taggings.each do |tagging|

      name = tagging.tag.name

      if new_tags.index(name) == nil
        tagging.destroy
        tag = Tag.find_by_name(name)
        tag.destroy if tag.taggings_count == 0
      end

    end

    # add tags

    (new_tags - old_tags).each do |name|

      tag = Tag.find_by_name(name);

      if tag.nil?
        tag = Tag.new(:name => name)
        tag.save
      end

      Tagging.new(:tag_id => tag.id,
          :taggable_type => taggable.class.to_s,
          :taggable_id => taggable.id,
          :user_id => tagger.id).save
    end

  end

  def update_credits(creditable, params)
    
    # First delete old creditations:
    creditable.creditors.each do |c|
      c.destroy
    end
    
    # Then create new creditations:
    
    # Current user
    if (params[:credits_me].downcase == 'true')
      c = Creditation.new(:creditor_type => 'User', :creditor_id => current_user.id, :creditable_type => creditable.class.to_s, :creditable_id => creditable.id)
      c.save
    end
    
    # Friends + other users
    user_ids = parse_comma_seperated_string(params[:credits_users])
    user_ids.each do |id|
      c = Creditation.new(:creditor_type => 'User', :creditor_id => id, :creditable_type => creditable.class.to_s, :creditable_id => creditable.id)
      c.save
    end
    
    # Networks (aka Groups)
    network_ids = parse_comma_seperated_string(params[:credits_groups])
    network_ids.each do |id|
      c = Creditation.new(:creditor_type => 'Network', :creditor_id => id, :creditable_type => creditable.class.to_s, :creditable_id => creditable.id)
      c.save
    end
    
  end
  
  def update_attributions(attributable, params)
    
    # First delete old attributions:
    attributable.attributors.each do |a|
      a.destroy
    end
    
    # Then create new attributions:
    
    # Workflows
    attributor_workflow_ids = parse_comma_seperated_string(params[:attributions_workflows])
    attributor_type = 'Workflow'
    attributor_workflow_ids.each do |id|
      a = Attribution.new(:attributor_type => attributor_type, :attributor_id => id, :attributable_type => attributable.class.to_s, :attributable_id  => attributable.id)
      a.save
    end
    
    # Files
    attributor_file_ids = parse_comma_seperated_string(params[:attributions_files])
    attributor_type = 'Blob'
    attributor_file_ids.each do |id|
      a = Attribution.new(:attributor_type => attributor_type, :attributor_id => id, :attributable_type => attributable.class.to_s, :attributable_id  => attributable.id)
      a.save
    end
    
  end
end
