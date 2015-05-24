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
