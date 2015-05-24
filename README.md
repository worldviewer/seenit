# Seen-It: A Reddit Clone for Interview Questions

Seen-It is a coding interview preparation tool designed to service graduates of coding bootcamps and other people looking to become employed as a full-stack web developer.

# Technologies

* Ruby on Rails
* Bootstrap
* SQLlite database
* Nokogiri web scraper using a rake script to build a seeds.rb database seed file
* Authorization with Pundit
* Authentication with Devise
* Image uploads with Paperclip
* Act-as-Votable gem

# Installation

```
mkdir seenit

git clone https://github.com/worldviewer/seenit

bundle install

rails server
```

# Addendum: How to Add Annotations to a Ruby Project

I found that there aren't currently any functional, simple reference designs on how to do this, so I will create one here with this project.

## Part 1: Setting up the Annotator (2.0) on the front end

See doc's at http://docs.annotatorjs.org/en/latest/modules/storage.html

In rails, this involves adding the javascript_include_tag call to 
'annotator.min' at the top of this application.html.erb file.

That annotator.min file referenced above should be placed at
app/vendor/assets/javascripts/annotator.min.js.

Rails requires yet another change, in the file at
app/assets/images/javascripts/application.js ...

```
//= require annotator.min
```

With those two changes in place, and once jQuery is finished loading,
it is at this point possible to simply type the following four lines
of code into the console.  Of course, as you can see, it will alternatively
work to simply include it at the end of the application.html.erb body,
within script tags.

Of course, please note that -- at this point -- there is not yet any
actual storage of annotations occurring, and if you attempt to save an
annotation, a flash message will appear saying as much at the top of the
screen.

Annotator requires some client-side JavaScript in order to load the UI.
That code, which follows, should go into ...

app/views/layouts/application.html.erb


```
<script>
// Wait for jQuery to load, then ...
$(document).ready(function() {

		// Instantiate the Annotator application
		var app = new annotator.App();

		// Use the standard user interface
		app.include(annotator.ui.main);

		// Use the standard remote storage
		app.include(annotator.storage.http);

		app.start();
		console.log("Annotations started!");
	});
</script>
```

It's a good idea to get to validate that this works before continuing on to add in a back end.  When you load the site, and select text on the site, does the Annotator tool pop up?

## Part 2: Setting up a datastore to persist annotations on the back end, with Ruby on Rails.  I'll just assume the default SQLlite database

### First, create a set of routes

They should correspond with the routes listed at http://docs.annotatorjs.org/en/v1.2.x/storage.html:

* root
* index
* create
* read
* update
* delete
* search

```
Rails.application.routes.draw do
	get 'annotator/' => 'annotator#root'
	get 'annotator/annotations' => 'annotator#index'
	post 'annotator/annotations' => 'annotator#create'
	get 'annotator/annotations/:id' => 'annotator#read', as => 'annotation_read'
	put 'annotator/annotations/:id' => 'annotator#update'
	delete 'annotator/annotations/:id' => 'annotator#delete'
	get 'annotator/search' => 'annotator#search'
end
```

### Next, create a new annotation model & migration

The new model should include the id:string and text:text data fields, like so:

```
rails g model annotation annotator_schema_version text:text quote:text uri ranges:text user consumer tags:text permissions:text

rails g migration CreateAnnotations
```

Validate that the migration file looks something like:

```
class CreateAnnotations < ActiveRecord::Migration
  def change
    create_table :annotations do |t|
      t.timestamps
      t.string :annotator_schema_version
      t.text :text
      t.text :quote
      t.string :uri
      t.text :ranges
      t.string :user
      t.string :consumer
      t.text :tags
      t.text :permissions
    end
  end
end
```

Then, create the Annotation database table with

```
rake db:migrate
```

You will want to think about how you are going to implement your table.  If you look at Annotator's JSON structure, it's two levels deep.  One way to do this might be to serialize the more complex structures, like this:

```
class Annotation < ActiveRecord::Base
	serialize :ranges, JSON
	serialize :tags, JSON
	serialize :permissions, JSON
end
```

Or, if the controller needs to work with them at all, the ranges could be alternatively implemented as a table.  The migration would look something like:

```
create_table :annotator_store_ranges do |t|
	t.references :annotation, index: true
	t.string :start
	t.string :end
	t.integer :start_offset
	t.integer :end_offset
	t.timestamps
end
```

### Now, create a controller to handle these Annotator API requests

```
rails g controller annotation root index create read update delete search
```

That will generate a file at app/controllers/annotation_controller.rb, which should look something like this:

```
class AnnotationController < ApplicationController
  skip_before_filter :verify_authenticity_token
  respond_to :xml, :json

  def root
    @info = {name: 'Annotator JS API'}

    render json: @info
  end

  def index
    @results = Annotation.all
    render json: @results
  end

  # Note that :see_other is a 303
  def create
    @annotation = Annotation.create(incoming)
    redirect_to annotation_read_path(@annotation), status: :see_other
  end

  def read
    @annotation = Annotation.find(params[:id])

    if @annotation
      render json: @annotation
    else
      # :not_found is status code 404
      head :not_found
    end
  end

  def update
    @annotation = Annotation.find(params[:id])

    if @annotation and @annotation.update_attributes(incoming)
      redirect_to annotation_read_path(@annotation), status: :see_other
    else
      head :not_found
    end
  end

  def delete
    @annotation = Annotation.find(params[:id])
    if @annotation and @annotation.destroy

      # Note that :no_content is status code 204
      head :no_content
    else
      head :not_found
    end
  end

  # Note that the response MUST include the total count, or the
  # annotations will not persist when the page is reloaded
  def search
    results = Annotation.where(uri: params[:uri])
    if results
      @response_wrapper = {total: results.count, rows: results}

      render json: @response_wrapper
    else
      head :not_found
    end
  end

  private

    # Note that ranges MUST be specified as a nested JSON structure
    # or they will not be properly transferred.

    # See http://docs.annotator.js.org/en/apidocs/annotation-format.html
    # for more information about the Annotation JSON format.
    def incoming
      params.require(:annotation).permit(:id, :annotator_schema_version, :text, :quote, :uri, { ranges: [ :start, :end, :startOffset, :endOffset] }, :user, :consumer, :tags, :permissions, :created_at, :updated_at);
    end

end

```

At this point, we will still run into issues with storing annotations.  If you look at the console reported back from Ruby on Rails, you'll see why: It's trying to POST the annotations to the wrong API route:

```
Started POST "/store/annotations" for ::1 at 2015-05-23 22:03:07 -0700

ActionController::RoutingError (No route matches [POST] "/store/annotations"):
```

This brings us to step 3!

## Part 3: Wire up the Annotator.js client to talk to our API

We have to revisit that client side javascript in the app/views/layouts/application.html.erb file:

```
<script>
// Wait for jQuery to load, then ...
$(document).ready(function() {

		var currentPage = window.location.href;

		var pageUri = function() {
			return {
				beforeAnnotationCreated: function (ann) {
					ann.uri = currentPage;
				}
			}
		};

		// Instantiate the Annotator application
		var app = new annotator.App();

		// Use the standard user interface
		app.include(annotator.ui.main, {element: document.body});

		// Configure the http() module to address the
		// annotations API
		app.include(annotator.storage.http, {
			prefix: currentPage + 'annotator'
		});

		// Send the current page
		app.include(pageUri);

		// Use the promise returned from start to load
		// annotations from the storage component
		app.start()
		.then(function() {
			app.annotations.load({uri: currentPage});
			console.log("Annotations loaded!");

		});
		console.log("Annotations started!");
	});
</script>

```
