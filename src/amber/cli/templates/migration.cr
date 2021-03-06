require "./field.cr"

module Amber::CLI
  class Migration < Teeplate::FileTree
    include Amber::CLI::Helpers
    directory "#{__DIR__}/migration/empty"

    @name : String
    @fields : Array(Field)
    @database : String
    @timestamp : String
    @primary_key : String

    def initialize(@name, fields)
      @fields = fields.map { |field| Field.new(field) }
      @database = database
      @timestamp = Time.now.to_s("%Y%m%d%H%M%S")
      @fields = fields.map { |field| Field.new(field, database: @database) }
      @fields += %w(created_at:time updated_at:time).map do |f|
        Field.new(f, hidden: true, database: @database)
      end
      @timestamp = Time.now.to_s("%Y%m%d%H%M%S")
      @primary_key = primary_key
    end

    def create_index_for_reference_fields_sql
      sql_statements = reference_fields.map do |field|
        create_index_for_reference_field_sql(field)
      end
      sql_statements.join("\n")
    end

    def create_table_sql
      <<-SQL
      CREATE TABLE #{@name}s (
        #{@primary_key},
        #{create_table_fields_sql}
      );
      SQL
    end

    def database
      if File.exists?(AMBER_YML) &&
         (yaml = YAML.parse(File.read AMBER_YML)) &&
         (database = yaml["database"]?)
        database.to_s
      else
        return "pg"
      end
    end

    def drop_table_sql
      "DROP TABLE IF EXISTS #{@name}s;"
    end

    def primary_key
      case @database
      when "pg"
        "id BIGSERIAL PRIMARY KEY"
      when "mysql"
        "id BIGINT NOT NULL AUTO_INCREMENT PRIMARY KEY"
      when "sqlite"
        "id INTEGER NOT NULL PRIMARY KEY"
      else
        "id INTEGER NOT NULL PRIMARY KEY"
      end
    end

    private def create_index_for_reference_field_sql(field : Field)
      index_name = "#{@name.underscore}_#{field.name}_id_idx"
      <<-SQL
      CREATE INDEX #{index_name} ON #{@name}s (#{field.name}_id);
      SQL
    end

    private def create_table_field_sql(field : Field)
      "#{field.name}#{field.reference? ? "_id" : ""} #{field.db_type}"
    end

    private def create_table_fields_sql
      @fields.map { |field| create_table_field_sql(field) }.join(",\n  ")
    end

    private def reference_fields
      @fields.select(&.reference?)
    end
  end
end
