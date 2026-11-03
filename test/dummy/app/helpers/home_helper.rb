# frozen_string_literal: true

module HomeHelper
  # FlatPack already depends on pagy. Pagination still wants a pagy-shaped
  # object plus pagy_url_for. These two tables keep separate page params, so
  # a single Pagy instance would not fit. PageNav is that object.
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
