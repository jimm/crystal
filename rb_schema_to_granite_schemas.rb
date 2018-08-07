#!/usr/bin/env ruby
#
# For usage, run rb_schema_to_granite_schemas.rb -h
#
# Outputs Granite (https://github.com/amberframework/granite) model files by
# reading a Ruby on Rails schema.rb file.

require 'fileutils'
require 'pathname'
require 'optparse'
require 'active_support'
require 'active_support/core_ext/string/inflections'

Options = Struct.new(
  :schema_file, :output_dir, :models, :print_model, :fk_mappings
)
# Unfortunately, this has to be global because there's no way to pass
# it in to the methods create_table and friends.
$args = Options.new(nil, nil, [], nil, {})

module ActiveRecord
  class Schema
    def self.init(args)
      @@args = args
    end

    def self.define(_info, &block)
      new.instance_eval(&block)
    end

    def create_table(name, options)
      yield Table.new(name, options)
    end

    def add_index(*_args)
      # nop
    end

    def add_foreign_key(*_args)
      # nop
    end
  end
end

class Field
  attr_accessor :name, :type, :options
  def initialize(name, type, options)
    @name, @type, @options = name, type, options
  end
  def nullable?
    options[:null] != false
  end
  def not_nullable?
    options[:null] == false
  end
end


class Table
  FIELD_TYPES = {
    integer: 'Int32',
    decimal: 'Float',
    string: 'String',
    text: 'String',
    datetime: 'Time',
    time: 'Time',
    date: 'Date',
    boolean: 'Bool',
    uuid: 'String'
  }

  @@tables = {}                 # k = table name, v = table

  attr_accessor :name, :options, :fields, :foreign_keys, :has_many_associations

  def self.all_tables
    @@tables.values
  end

  def self.check_for_duplicate_names
    names = all_tables.map(&:name).map(&:singularize)
    if names.length > names.uniq.length
      $stderr.puts "warning: there are duplicate names"
      $stderr.puts names.sort.join("\n")
      exit 1
    end
  end

  def initialize(name, options={})
    @name, @options = name, options
    @name = name
    @fields = []
    @foreign_keys = []
    @has_many_associations = []
    @adapter = 'mysql'          # TODO

    @@tables[name] = self
  end

  def integer(name, options={})
    if name =~ /(\w+)_id$/
      @foreign_keys << Field.new($1, full_class_name($1), options)
    else
      @fields << Field.new(name, ':integer', options)
    end
  end

  def field_type_from_db_type(db_type, options)
    t = FIELD_TYPES[db_type].dup || db_type.to_s
    unless options[:nullable] == false
      t << '?'
    end
    if options[:default]
      default = options[:default]
      unless default.kind_of?(Numeric) || t.start_with?("Bool")
        default = "\"#{default}\""
      end
      t = "{type: #{t}, default: #{default}}"
    end
    t
  end

  %i(string text datetime date time uuid boolean float decimal).each do |type|
    define_method(type) do |name, options={}|
      case name
      when 'created_at'
        if @updated_at
          @timestamps = true
        else
          @created_at = true
        end
      when 'updated_at'
        if @created_at
          @timestamps = true
        else
          @updated_at = true
        end
      else
        @fields << Field.new(name, field_type_from_db_type(type, options), options)
      end
    end
  end

  def method_missing(sym, *args)
    # nop
  end

  def create_has_many_references
    @foreign_keys.each do |fk|
      t = @@tables[fk.name.pluralize]
      if t
        t.has_many_associations << Field.new(@name, full_class_name, {})
      end
    end
  end

  def model_name(name=@name)
    ActiveSupport::Inflector.classify(name)
  end

  def full_class_name(name=@name)
    model_name(name)
  end

  def schema(prefix = "  ")
    str = <<~EOS
    #{prefix}adapter #@adapter
    #{prefix}table_name #@name
    EOS

    fields = @fields.map do |field|
      "#{field.name} : #{field.type}"
    end
    fields += @foreign_keys.map do |field|
      "#{field.name}_id : Int32#{field.options[:nullable] == false ? '' : '?'}"
    end
    str << prefix + fields.join("\n#{prefix}") + "\n"

    if @timetsamps
      str << "#{prefix}timestamps\n"
    end

    str << assocs_schema(prefix, @foreign_keys, "belongs_to", true)
    str << assocs_schema(prefix, @has_many_associations, "has_many", false)
  end

  def assocs_schema(prefix, assocs, assoc_name, is_belongs_to)
    return "" if assocs.empty?

    assocs = assocs.map do |assoc|
      t = $args.fk_mappings[assoc.type.to_s] || assoc.type
      ":#{assoc.name}, #{t}#{is_belongs_to ? belongs_to_suffix : ''}"
    end
    s = "\n#{prefix}#{assoc_name} "
    s + assocs.join("#{s}") + "\n"
  end

  def to_s
    "class #{full_class_name} < Granite::ORM::Base\n#{schema}end"
  end
end


class String
  include ActiveSupport::Inflector
end

if __FILE__ == $PROGRAM_NAME

  op = OptionParser.new do |opts|
    opts.on('-sFILE', '--schema=FILE', 'Rails schema.rb file') do |f|
      $args.schema_file = f
    end
    opts.on('-mNAME', '--module=NAME', 'Schema module prefix (default is nil)') do |name|
      $args.class_name = name
    end
    opts.on('-oDIR', '--output-dir=DIR', 'Schema directory') do |dir|
      $args.output_dir = dir
    end
    opts.on('-d', '--model=MODEL', 'Comma-separated list of models to generate (default is all)') do |val|
      $args.models += val.split(',').map(&:strip)
    end
    opts.on('-f', '--fk-mapping=STR', 'Comma-separated list of foreign key guess-name mappings') do |str|
      str.split(',').each do |s|
        old, new = s.strip.split(/[^\w]/)
        $args.fk_mappings[old] = new
      end
    end
    opts.on('-p', '--print-model', 'Output model with schema to stdout, do not generate file') do |_|
      $args.print_model = true
    end
    opts.on_tail('-h', '--help', 'Prints this help') do
      puts opts
      exit
    end
  end
  op.parse!

  if $args.schema_file.nil?
    $stderr.puts "error: schema file is required"
    puts op
    exit 1
  end
  if $args.output_dir.nil? && !$args.print_model
    $stderr.puts "error: output directory is required"
    puts op
    exit 1
  end

  if $args.output_dir
    p = Pathname.new($args.output_dir)
    p.mkpath
  end

  ActiveRecord::Schema.init($args)
  require $args.schema_file

  Table.check_for_duplicate_names
  Table.all_tables.each do |t|
    t.create_has_many_references
  end

  tables = Table.all_tables
  if $args.models && $args.models.length > 0
    tables.select! { |t| $args.models.include?(t.model_name) }
  end
  tables.each_with_index do |t, i|
    if $args.print_model
      puts() if i > 0
      puts t.to_s
    else
      File.open(File.join($args.output_dir, "#{t.name.singularize}.cr"), 'w') do |f|
        f.puts t.to_s
      end
    end
  end
end
