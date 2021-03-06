require File.dirname(__FILE__) + '/../test_helper'
require 'api_controller'
require 'xml/libxml'
require 'lib/rest'

include ActionView::Helpers::UrlHelper
include ActionController::UrlWriter

# Re-raise errors caught by the controller.
class ApiController; def rescue_action(e) raise e end; end

class ApiControllerTest < Test::Unit::TestCase

  fixtures :workflows, :users, :content_types, :licenses, :ontologies, :predicates, :packs

  def setup
    @controller = ApiController.new
    @request    = TestRequestWithQuery.new
    @response   = ActionController::TestResponse.new
  end

  def test_workflows

    existing_workflows = Workflow.find(:all)

    login_as(:john)

    title        = "Unique tags"
    title2       = "Unique tags again"
    license_type = "by-sa"
    content_type = "application/vnd.taverna.scufl+xml"
    description  = "A workflow description."

    content = Base64.encode64(File.read('test/fixtures/files/workflow_dilbert.xml'))

    # post a workflow

    rest_request(:post, 'workflow', "<?xml version='1.0'?>
      <workflow>
        <title>#{title}</title>
        <description>#{description}</description>
        <license-type>#{license_type}</license-type>
        <content-type>#{content_type}</content-type>
        <content>#{content}</content>
      </workflow>")

    assert_response(:success)

    extra_workflows = Workflow.find(:all) - existing_workflows

    assert_equal(extra_workflows.length, 1)

    @workflow_id = extra_workflows.first.id

    # get the workflow

    response = rest_request(:get, 'workflow', nil, "id" => @workflow_id,
        "elements" => "title,description,license-type,content-type,content")

    assert_response(:success)
  
    assert_equal(title,        response.find_first('/workflow/title').inner_xml)
    assert_equal(description,  response.find_first('/workflow/description').inner_xml)
    assert_equal(license_type, response.find_first('/workflow/license-type').inner_xml)
    assert_equal(content_type, response.find_first('/workflow/content-type').inner_xml)
    assert_equal(content,      response.find_first('/workflow/content').inner_xml)

    # it's private default, so make sure that another user can't get the
    # workflow

    setup
    login_as(:jane)

    rest_request(:get, 'workflow', nil, "id" => @workflow_id)

    assert_response(:unauthorized)
     
    # update the workflow

    setup
    login_as(:john)

    rest_request(:put, 'workflow', "<?xml version='1.0'?>
      <workflow>
        <title>#{title2}</title>
      </workflow>", "id" => @workflow_id)

    assert_response(:success)

    # get the updated workflow

    response = rest_request(:get, 'workflow', nil, "id" => @workflow_id,
        "elements" => "title,description")

    assert_response(:success)
  
    assert_equal(title2,      response.find_first('/workflow/title').inner_xml)
    assert_equal(description, response.find_first('/workflow/description').inner_xml)

    # delete the workflow

    rest_request(:delete, 'workflow', nil, "id" => @workflow_id)

    assert_response(:success)

    # try to get the deleted workflow

    rest_request(:get, 'workflow', nil, "id" => @workflow_id)

    assert_response(:not_found)
  end

  def test_files

    existing_files = Blob.find(:all)

    login_as(:john)

    title        = "Test file title"
    title2       = "Updated test file title"
    license_type = "by-sa"
    content_type = "text/plain"
    description  = "A description of the test file."

    content = Base64.encode64("This is the content of this test file.")

    # post a file

    rest_request(:post, 'file', "<?xml version='1.0'?>
      <file>
        <title>#{title}</title>
        <description>#{description}</description>
        <license-type>#{license_type}</license-type>
        <content-type>#{content_type}</content-type>
        <content>#{content}</content>
      </file>")

    assert_response(:success)

    extra_files = Blob.find(:all) - existing_files

    assert_equal(extra_files.length, 1)

    file = extra_files.first

    # get the file

    response = rest_request(:get, 'file', nil, "id" => file.id,
        "elements" => "title,description,license-type,content-type,content")

    assert_response(:success)

    assert_equal(title,        response.find_first('/file/title').inner_xml)
    assert_equal(description,  response.find_first('/file/description').inner_xml)
    assert_equal(license_type, response.find_first('/file/license-type').inner_xml)
    assert_equal(content_type, response.find_first('/file/content-type').inner_xml)
    assert_equal(content,      response.find_first('/file/content').inner_xml)

    # it's private default, so make sure that another user can't get the
    # file

    setup
    login_as(:jane)

    rest_request(:get, 'file', nil, "id" => file.id)

    assert_response(:unauthorized)
     
    # update the file

    setup
    login_as(:john)

    rest_request(:put, 'file', "<?xml version='1.0'?>
      <file>
        <title>#{title2}</title>
      </file>", "id" => file.id)

    assert_response(:success)

    # get the updated file

    response = rest_request(:get, 'file', nil, "id" => file.id,
        "elements" => "title,description")

    assert_response(:success)
  
    assert_equal(title2,      response.find_first('/file/title').inner_xml)
    assert_equal(description, response.find_first('/file/description').inner_xml)

    # delete the file

    rest_request(:delete, 'file', nil, "id" => file.id)

    assert_response(:success)

    # try to get the deleted file

    rest_request(:get, 'file', nil, "id" => file.id)

    assert_response(:not_found)
  end

  def test_packs

    existing_packs = Pack.find(:all)

    login_as(:john)

    title        = "A pack"
    title2       = "An updated pack"
    description  = "A pack description."

    # post a pack

    rest_request(:post, 'pack', "<?xml version='1.0'?>
      <pack>
        <title>#{title}</title>
        <description>#{description}</description>
        <permissions>
          <permission>
            <category>public</category>
            <privilege type='view'/>
            <privilege type='download'/>
          </permission>
        </permissions>
      </pack>")
    
    assert_response(:success)

    extra_packs = Pack.find(:all) - existing_packs

    assert_equal(extra_packs.length, 1)

    @pack_id = extra_packs.first.id

    # get the pack

    response = rest_request(:get, 'pack', nil, "id" => @pack_id,
        "elements" => "title,description")

    assert_response(:success)
  
    assert_equal(title,        response.find_first('/pack/title').inner_xml)
    assert_equal(description,  response.find_first('/pack/description').inner_xml)

    # make sure that another user can get the pack, since it's supposed to be
    # public

    setup;
    login_as(:jane)

    rest_request(:get, 'pack', nil, "id" => @pack_id)

    assert_response(:success)
     
    # update the pack

    setup
    login_as(:john)

    rest_request(:put, 'pack', "<?xml version='1.0'?>
      <pack>
        <title>#{title2}</title>
      </pack>", "id" => @pack_id)

    assert_response(:success)

    # get the updated pack

    response = rest_request(:get, 'pack', nil, "id" => @pack_id,
        "elements" => "title,description")

    assert_response(:success)
  
    assert_equal(title2,      response.find_first('/pack/title').inner_xml)
    assert_equal(description, response.find_first('/pack/description').inner_xml)

    # add an internal pack item

    existing_internal_pack_items = PackContributableEntry.find(:all)

    pack_uri     = rest_resource_uri(Pack.find(@pack_id))
    workflow_uri = rest_resource_uri(Workflow.find(1))
    comment1     = "It's an internal pack item."
    comment2     = "It's an updated internal pack item."

    rest_request(:post, 'internal-pack-item', "<?xml version='1.0'?>
      <internal-pack-item>
        <pack resource='#{pack_uri}'/>
        <item resource='#{workflow_uri}'/>
        <comment>#{comment1}</comment>
      </internal-pack-item>")

    assert_response(:success)

    extra_internal_pack_items = PackContributableEntry.find(:all) - existing_internal_pack_items

    assert_equal(extra_internal_pack_items.length, 1)

    @internal_pack_item_id = extra_internal_pack_items.first.id
    
    # get the internal pack item

    response = rest_request(:get, 'internal-pack-item', nil, "id" => @internal_pack_item_id)

    assert_response(:success)

    assert_equal(pack_uri,     response.find_first('/internal-pack-item/pack/@resource').value)
    assert_equal(workflow_uri, response.find_first('/internal-pack-item/item/*/@resource').value)
    assert_equal(comment1,     response.find_first('/internal-pack-item/comment').inner_xml)

    # update the internal pack item

    rest_request(:put, 'internal-pack-item', "<?xml version='1.0'?>
      <internal-pack-item>
        <comment>#{comment2}</comment>
      </internal-pack-item>", "id" => @internal_pack_item_id)

    assert_response(:success)

    # get the updated internal pack item

    response = rest_request(:get, 'internal-pack-item', nil, "id" => @internal_pack_item_id)

    assert_response(:success)

    assert_equal(comment2, response.find_first('/internal-pack-item/comment').inner_xml)

    # delete the internal pack item

    rest_request(:delete, 'internal-pack-item', nil, "id" => @internal_pack_item_id)

    assert_response(:success)

    # try to get the deleted internal pack item

    response = rest_request(:get, 'internal-pack-item', nil, "id" => @internal_pack_item_id)

    assert_response(:not_found)

    # add an external pack item

    existing_external_pack_items = PackRemoteEntry.find(:all)

    external_uri  = "http://example.com/"
    alternate_uri = "http://example.com/alternate"
    comment3      = "It's an external pack item."
    comment4      = "It's an updated external pack item."
    title         = "Title for the external pack item."

    rest_request(:post, 'external-pack-item', "<?xml version='1.0'?>
      <external-pack-item>
        <pack resource='#{pack_uri}'/>
        <title>#{title}</title>
        <uri>#{external_uri}</uri>
        <alternate-uri>#{alternate_uri}</alternate-uri>
        <comment>#{comment3}</comment>
      </external-pack-item>")

    assert_response(:success)

    extra_external_pack_items = PackRemoteEntry.find(:all) - existing_external_pack_items

    assert_equal(extra_external_pack_items.length, 1)

    @external_pack_item_id = extra_external_pack_items.first.id
    
    # get the external pack item

    response = rest_request(:get, 'external-pack-item', nil, "id" => @external_pack_item_id,
      "elements" => "pack,title,uri,alternate-uri,comment")

    assert_response(:success)

    assert_equal(pack_uri,      response.find_first('/external-pack-item/pack/@resource').value)
    assert_equal(external_uri,  response.find_first('/external-pack-item/uri').inner_xml)
    assert_equal(alternate_uri, response.find_first('/external-pack-item/alternate-uri').inner_xml)
    assert_equal(comment3,      response.find_first('/external-pack-item/comment').inner_xml)

    # update the external pack item

    rest_request(:put, 'external-pack-item', "<?xml version='1.0'?>
      <external-pack-item>
        <comment>#{comment4}</comment>
      </external-pack-item>", "id" => @external_pack_item_id)

    assert_response(:success)

    # get the updated external pack item

    response = rest_request(:get, 'external-pack-item', nil, "id" => @external_pack_item_id)

    assert_response(:success)

    assert_equal(comment4, response.find_first('/external-pack-item/comment').inner_xml)

    # delete the external pack item

    rest_request(:delete, 'external-pack-item', nil, "id" => @external_pack_item_id)

    assert_response(:success)

    # try to get the deleted external pack item

    response = rest_request(:get, 'external-pack-item', nil, "id" => @external_pack_item_id)

    assert_response(:not_found)

    # delete the pack

    rest_request(:delete, 'pack', nil, "id" => @pack_id)

    assert_response(:success)

    # try to get the deleted pack

    rest_request(:get, 'pack', nil, "id" => @pack_id)

    assert_response(:not_found)
  end

  def test_comments

    login_as(:john)

    # post a workflow to test with

    content = Base64.encode64(File.read('test/fixtures/files/workflow_dilbert.xml'))

    existing_workflows = Workflow.find(:all)

    rest_request(:post, 'workflow', "<?xml version='1.0'?>
      <workflow>
        <title>Unique tags</title>
        <description>A workflow description.</description>
        <license-type>by-sa</license-type>
        <content-type>application/vnd.taverna.scufl+xml</content-type>
        <content>#{content}</content>
      </workflow>")

    assert_response(:success)

    extra_workflows = Workflow.find(:all) - existing_workflows

    assert_equal(extra_workflows.length, 1)

    workflow = extra_workflows.first
    workflow_url = rest_resource_uri(workflow)

    # post a comment

    comment_text  = "a test comment"
    comment_text2 = "an updated test comment"

    existing_comments = Comment.find(:all)

    rest_request(:post, 'comment', "<?xml version='1.0'?>
      <comment>
        <comment>#{comment_text}</comment>
        <subject resource='#{workflow_url}'/>
      </comment>")

    assert_response(:success)

    extra_comments = Comment.find(:all) - existing_comments 
    
    assert_equal(extra_comments.length, 1)

    comment = extra_comments.first

    # update the comment (which should fail)

    rest_request(:put, 'comment', "<?xml version='1.0'?>
      <comment>
        <comment>#{comment_text2}</comment>
      </comment>", "id" => comment.id)

    assert_response(:unauthorized)
    
    # delete the comment

    rest_request(:delete, 'comment', nil, "id" => comment.id)

    assert_response(:success)

    # try to get the deleted comment

    rest_request(:get, 'comment', nil, "id" => comment.id)

    assert_response(:not_found)
  end

  def test_ratings

    login_as(:john)

    # post a workflow to test with

    content = Base64.encode64(File.read('test/fixtures/files/workflow_dilbert.xml'))

    existing_workflows = Workflow.find(:all)

    rest_request(:post, 'workflow', "<?xml version='1.0'?>
      <workflow>
        <title>Unique tags</title>
        <description>A workflow description.</description>
        <license-type>by-sa</license-type>
        <content-type>application/vnd.taverna.scufl+xml</content-type>
        <content>#{content}</content>
      </workflow>")

    assert_response(:success)

    extra_workflows = Workflow.find(:all) - existing_workflows

    assert_equal(extra_workflows.length, 1)

    workflow = extra_workflows.first
    workflow_url = rest_resource_uri(workflow)

    # post a rating

    existing_ratings = Rating.find(:all)

    rest_request(:post, 'rating', "<?xml version='1.0'?>
      <rating>
        <rating>4</rating>
        <subject resource='#{workflow_url}'/>
      </rating>")

    assert_response(:success)

    extra_ratings = Rating.find(:all) - existing_ratings 
    
    assert_equal(extra_ratings.length, 1)

    rating = extra_ratings.first

    assert_equal(rating.user, users(:john));
    assert_equal(rating.rateable, workflow);
    assert_equal(rating.rating, 4);

    # update the rating (which should fail)

    rest_request(:put, 'rating', "<?xml version='1.0'?>
      <rating>
        <rating>3</rating>
      </rating>", "id" => rating.id)

    assert_response(:success)
    
    rating.reload

    assert_equal(rating.rating, 3);

    # delete the rating

    rest_request(:delete, 'rating', nil, "id" => rating.id)

    assert_response(:success)

    # try to get the deleted rating

    rest_request(:get, 'rating', nil, "id" => rating.id)

    assert_response(:not_found)
  end

  def test_favourites

    login_as(:john)

    # post a workflow to test with

    content = Base64.encode64(File.read('test/fixtures/files/workflow_dilbert.xml'))

    existing_workflows = Workflow.find(:all)

    rest_request(:post, 'workflow', "<?xml version='1.0'?>
      <workflow>
        <title>Unique tags</title>
        <description>A workflow description.</description>
        <license-type>by-sa</license-type>
        <content-type>application/vnd.taverna.scufl+xml</content-type>
        <content>#{content}</content>
      </workflow>")

    assert_response(:success)

    extra_workflows = Workflow.find(:all) - existing_workflows

    assert_equal(extra_workflows.length, 1)

    workflow = extra_workflows.first
    workflow_url = rest_resource_uri(workflow)

    # post a favourite

    existing_favourites = Bookmark.find(:all)

    rest_request(:post, 'favourite', "<?xml version='1.0'?>
      <favourite>
        <object resource='#{workflow_url}'/>
      </favourite>")

    assert_response(:success)

    extra_favourites = Bookmark.find(:all) - existing_favourites 
    
    assert_equal(extra_favourites.length, 1)

    favourite = extra_favourites.first

    # delete the favourite

    rest_request(:delete, 'favourite', nil, "id" => favourite.id)

    assert_response(:success)

    # try to get the deleted favourite

    rest_request(:get, 'favourite', nil, "id" => favourite.id)

    assert_response(:not_found)
  end

  def test_taggings

    login_as(:john)

    # post a workflow to test with

    content = Base64.encode64(File.read('test/fixtures/files/workflow_dilbert.xml'))

    existing_workflows = Workflow.find(:all)

    rest_request(:post, 'workflow', "<?xml version='1.0'?>
      <workflow>
        <title>Unique tags</title>
        <description>A workflow description.</description>
        <license-type>by-sa</license-type>
        <content-type>application/vnd.taverna.scufl+xml</content-type>
        <content>#{content}</content>
      </workflow>")

    assert_response(:success)

    extra_workflows = Workflow.find(:all) - existing_workflows

    assert_equal(extra_workflows.length, 1)

    workflow = extra_workflows.first
    workflow_url = rest_resource_uri(workflow)

    # post a tagging

    existing_taggings = Tagging.find(:all)

    rest_request(:post, 'tagging', "<?xml version='1.0'?>
      <tagging>
        <subject resource='#{workflow_url}'/>
        <label>my test tag</label>
      </tagging>")

    assert_response(:success)

    extra_taggings = Tagging.find(:all) - existing_taggings 
    
    assert_equal(extra_taggings.length, 1)

    tagging = extra_taggings.first

    assert_equal(tagging.user, users(:john));
    assert_equal(tagging.taggable, workflow);
    assert_equal(tagging.label, 'my test tag');

    # update the tagging (which should fail)

    rest_request(:put, 'tagging', "<?xml version='1.0'?>
      <tagging>
        <label>fail</label>
      </tagging>", "id" => tagging.id)

    assert_response(400)
    
    # delete the tagging

    rest_request(:delete, 'tagging', nil, "id" => tagging.id)

    assert_response(:success)

    # try to get the deleted tagging

    rest_request(:get, 'tagging', nil, "id" => tagging.id)

    assert_response(:not_found)
  end

  def test_ontologies

    existing_ontologies = Ontology.find(:all)

    login_as(:john)

    title       = "Test ontology title"
    title2      = "Updated test ontology title"
    uri         = "http://example.com/ontology"
    prefix      = "test prefix"
    description = "A description of the ontology."

    # post an ontology

    rest_request(:post, 'ontology', "<?xml version='1.0'?>
      <ontology>
        <title>#{title}</title>
        <description>#{description}</description>
        <uri>#{uri}</uri>
        <prefix>#{prefix}</prefix>
      </ontology>")

    assert_response(:success)

    extra_ontologies = Ontology.find(:all) - existing_ontologies

    assert_equal(extra_ontologies.length, 1)

    ontology = extra_ontologies.first

    # get the ontology

    response = rest_request(:get, 'ontology', nil, "id" => ontology.id,
        "elements" => "title,description,uri,prefix")

    assert_response(:success)

    assert_equal(title,       response.find_first('/ontology/title').inner_xml)
    assert_equal(description, response.find_first('/ontology/description').inner_xml)
    assert_equal(uri,         response.find_first('/ontology/uri').inner_xml)
    assert_equal(prefix,      response.find_first('/ontology/prefix').inner_xml)

    # update the ontology

    rest_request(:put, 'ontology', "<?xml version='1.0'?>
      <ontology>
        <title>#{title2}</title>
      </ontology>", "id" => ontology.id)

    assert_response(:success)

    # get the updated ontology

    response = rest_request(:get, 'ontology', nil, "id" => ontology.id,
        "elements" => "title,description")

    assert_response(:success)
  
    assert_equal(title2,      response.find_first('/ontology/title').inner_xml)
    assert_equal(description, response.find_first('/ontology/description').inner_xml)

    # delete the ontology

    rest_request(:delete, 'ontology', nil, "id" => ontology.id)

    assert_response(:success)

    # try to get the deleted ontology

    rest_request(:get, 'ontology', nil, "id" => ontology.id)

    assert_response(:not_found)
  end

  def test_predicates

    existing_predicates = Predicate.find(:all)

    login_as(:john)

    title            = "Test predicate title"
    title2           = "Updated test predicate title"
    ontology         = ontologies(:test_ontology_1)
    ontology_url     = rest_resource_uri(ontology)
    phrase           = "test phrase"
    description      = "A description of the predicate."
    description_html = "<p>A description of the predicate.</p>"
    equivalent_to    = "test equivalent_to"

    # post a predicate

    rest_request(:post, 'predicate', "<?xml version='1.0'?>
      <predicate>
        <title>#{title}</title>
        <ontology resource='#{ontology_url}'/>
        <phrase>#{phrase}</phrase>
        <description>#{description}</description>
        <equivalent-to>#{equivalent_to}</equivalent-to>
      </predicate>")

    assert_response(:success)

    extra_predicates = Predicate.find(:all) - existing_predicates

    assert_equal(extra_predicates.length, 1)

    predicate = extra_predicates.first

    # get the predicate

    response = rest_request(:get, 'predicate', nil, "id" => predicate.id,
        "elements" => "title,description,phrase,equivalent-to")

    assert_response(:success)

    assert_equal(title,         response.find_first('/predicate/title').inner_xml)
    assert_equal(description,   response.find_first('/predicate/description').inner_xml)
    assert_equal(phrase,        response.find_first('/predicate/phrase').inner_xml)
    assert_equal(equivalent_to, response.find_first('/predicate/equivalent-to').inner_xml)

    # update the predicate

    rest_request(:put, 'predicate', "<?xml version='1.0'?>
      <predicate>
        <title>#{title2}</title>
      </predicate>", "id" => predicate.id)

    assert_response(:success)

    # get the updated predicate

    response = rest_request(:get, 'predicate', nil, "id" => predicate.id,
        "elements" => "title,description")

    assert_response(:success)
  
    assert_equal(title2,      response.find_first('/predicate/title').inner_xml)
    assert_equal(description, response.find_first('/predicate/description').inner_xml)

    # delete the predicate

    rest_request(:delete, 'predicate', nil, "id" => predicate.id)

    assert_response(:success)

    # try to get the deleted predicate

    rest_request(:get, 'predicate', nil, "id" => predicate.id)

    assert_response(:not_found)
  end

  def test_relationships

    existing_relationships = Relationship.find(:all)

    login_as(:john)

    subject_url   = rest_resource_uri(workflows(:workflow_branch_choice))
    predicate_url = rest_resource_uri(predicates(:test_predicate_1))
    objekt_url    = rest_resource_uri(workflows(:workflow_dilbert))
    context_url   = rest_resource_uri(packs(:pack_1))

    # post a relationship

    rest_request(:post, 'relationship', "<?xml version='1.0'?>
      <relationship>
        <subject resource='#{subject_url}'/>
        <predicate resource='#{predicate_url}'/>
        <object resource='#{objekt_url}'/>
        <context resource='#{context_url}'/>
      </relationship>")

    assert_response(:success)

    extra_relationships = Relationship.find(:all) - existing_relationships

    assert_equal(extra_relationships.length, 1)

    relationship = extra_relationships.first

    # get the relationship

    response = rest_request(:get, 'relationship', nil, "id" => relationship.id,
        "elements" => "user,subject,predicate,object,context")

    assert_response(:success)

    assert_equal(subject_url,   response.find_first('/relationship/subject/*/@resource').value)
    assert_equal(predicate_url, response.find_first('/relationship/predicate/@resource').value)
    assert_equal(objekt_url,    response.find_first('/relationship/object/*/@resource').value)
    assert_equal(context_url,   response.find_first('/relationship/context/*/@resource').value)

    # delete the relationship

    rest_request(:delete, 'relationship', nil, "id" => relationship.id)

    assert_response(:success)

    # try to get the deleted relationship

    rest_request(:get, 'relationship', nil, "id" => relationship.id)

    assert_response(:not_found)
  end

  private

  def rest_request(method, uri, data = nil, query = {})

    @request.query_parameters!(query) if query

    @request.env['RAW_POST_DATA'] = data if data

    # puts "Sending: #{data.inspect}"

    case method
      when :get;    get(:process_request,     { :uri => uri } )
      when :post;   post(:process_request,    { :uri => uri } )
      when :put;    put(:process_request,     { :uri => uri } )
      when :delete; delete(:process_request,  { :uri => uri } )
    end

    # puts "Response: #{LibXML::XML::Parser.string(@response.body).parse.root.to_s}"

    LibXML::XML::Parser.string(@response.body).parse
  end
end

# Custom version of the TestRequest, so that I can set the query parameters of
# a request.

class TestRequestWithQuery < ActionController::TestRequest

  def query_parameters!(hash)
    @custom_query_parameters = hash
  end


  def recycle!
    super

    if @custom_query_parameters
      self.query_parameters = @custom_query_parameters
      @custom_query_parameters = nil
    end
  end
end

