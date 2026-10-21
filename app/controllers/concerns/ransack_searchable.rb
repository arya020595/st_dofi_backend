module RansackSearchable
  extend ActiveSupport::Concern

  # Builds @q from params[:q] and returns the filtered/sorted relation, ready for pagy.
  # default_sort is only applied when the caller didn't request any sort (e.g. "created_at desc").
  def apply_ransack_search(scope, default_sort: nil)
    @q = scope.ransack(params[:q])
    @q.sorts = default_sort if @q.sorts.empty? && default_sort.present?
    @q.result
  end
end
