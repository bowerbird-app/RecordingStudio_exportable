class AddAuthorToArticles < ActiveRecord::Migration[8.1]
  def change
    add_reference :articles, :author, type: :uuid, null: true, foreign_key: true

    reversible do |dir|
      dir.up do
        default_author_id = select_value(<<~SQL.squish)
          SELECT id FROM authors ORDER BY created_at ASC NULLS LAST, id ASC LIMIT 1
        SQL

        if default_author_id.nil?
          execute <<~SQL.squish
            INSERT INTO authors (id, name, bio, created_at, updated_at)
            VALUES (gen_random_uuid(), 'Unknown Author', '', NOW(), NOW())
          SQL

          default_author_id = select_value(<<~SQL.squish)
            SELECT id FROM authors ORDER BY created_at ASC NULLS LAST, id ASC LIMIT 1
          SQL
        end

        execute <<~SQL.squish
          UPDATE articles
          SET author_id = #{connection.quote(default_author_id)}
          WHERE author_id IS NULL
        SQL
      end
    end

    change_column_null :articles, :author_id, false
  end
end
