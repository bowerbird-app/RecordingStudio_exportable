# frozen_string_literal: true

module HomeHelper
  # FlatPack::Pagination asks for a pagy-shaped object and pagy_url_for.
  # The home tables page with their own query params, so this is not a Pagy model.
  PageNav = Struct.new(:page, :pages, :page_param, :extra, keyword_init: true) do
    def prev
      page > 1 ? page - 1 : nil
    end

    def next
      page < pages ? page + 1 : nil
    end

    def series
      (1..pages).to_a
    end

    def vars
      { page_param: page_param, extra: extra || {} }
    end
  end

  def pagy_url_for(pagy, page)
    page_param = pagy.vars.fetch(:page_param, :page)
    extra = pagy.vars.fetch(:extra, {})
    query = request.query_parameters.merge(extra).merge(page_param.to_s => page)
    path = request.path.presence || "/"
    "#{path}?#{query.to_query}"
  end
end
