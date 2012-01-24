#!/usr/bin/ruby

# This benchmark is based on Tokyo Cabinet's benchmark at
# http://alpha.mixi.co.jp/blog/?p=791
#
# On my environment at 2009/07/14:
# % for x in {0..9}; do ruby benchmark/write-many-small-items.rb $x; done
#                           user     system      total        real        memory
# Hash                  0.650000   0.130000   0.780000 (  0.799843)     46.957MB
# groonga: Hash: memory 0.650000   0.130000   0.780000 (  0.781058)     23.477MB
# groonga: Trie: memory 0.690000   0.180000   0.870000 (  0.862132)     15.516MB
# groonga: Hash: file   0.660000   0.120000   0.780000 (  0.780952)     23.480MB
# groonga: Trie: file   0.660000   0.190000   0.850000 (  0.867515)     15.520MB
# Localmemcache: file   0.900000   0.150000   1.050000 (  1.052692)     39.312MB
# TC: Hash: memory      0.480000   0.150000   0.630000 (  0.636297)     42.062MB
# TC: Tree: memory      0.440000   0.150000   0.590000 (  0.593117)     30.570MB
# TC: Hash: file        1.000000   1.820000   2.820000 (  2.989515)      2.160MB
# TC: Tree: file        0.720000   0.130000   0.850000 (  0.877557)      6.102MB
#
# CPU: Intel(R) Core(TM)2 Duo 2.33GHz
# Memory: 2GB
# Ruby: Debian GNU/Linux sid at 2009/07/14:
#       ruby 1.8.7 (2009-06-12 patchlevel 174) [x86_64-linux]
# groonga: HEAD at 2009/07/14: fdaf58df5dd0195c10624eabee3e3f522f4af3f9
# Ruby/Groonga: trunk at 2009/07/14: r479
# Localmemcache: HEAD at 2009/07/14: 3121629016344dfd10f7533ca8ec68a0006cca21
# Tokyo Cabinet: 1.4.29
# Tokyo Cabinet Ruby: 1.27
#
# NOTE:
# * groonga, Localmemcache and Tokyo Cabinet are built with "-O3" option.
# * Ruby bindings of them are built with "-O2" option.

require File.join(File.dirname(__FILE__), "common.rb")

n = 500000

values = []
n.times do |i|
  values << "%08d" % i
end

ruby_hash = {}
item("Hash") do
  values.each do |value|
    ruby_hash[value] = value
  end
end

begin
  base_dir = File.expand_path(File.join(File.dirname(__FILE__), ".."))
  $LOAD_PATH.unshift(File.join(base_dir, "ext", "groonga"))
  $LOAD_PATH.unshift(File.join(base_dir, "lib"))

  require 'groonga'
  tmp_dir = "/tmp/groonga"
  FileUtils.rm_rf(tmp_dir)
  FileUtils.mkdir(tmp_dir)
  Groonga::Context.default.encoding = :none
  @database = Groonga::Database.create(:path => "#{tmp_dir}/db")
  column_name = "value"

  groonga_hash = Groonga::Hash.create(:name => "Hash",
                                      :key_type => "ShortText")
  groonga_hash.define_column(column_name, "ShortText")
  item("groonga: Hash") do
    values.each do |value|
      groonga_hash.set_column_value(value, column_name, value)
    end
  end

  patricia_trie = Groonga::PatriciaTrie.create(:name => "PatriciaTrie",
                                               :key_type => "ShortText")
  patricia_trie.define_column(column_name, "ShortText")
  item("groonga: PatriciaTrie") do
    values.each do |value|
      patricia_trie.set_column_value(value, column_name, value)
    end
  end

  double_array_trie = Groonga::DoubleArrayTrie.create(:name => "DoubleArrayTrie",
                                                      :key_type => "ShortText")
  double_array_trie.define_column(column_name, "ShortText")
  item("groonga: DoubleArrayTrie") do
    values.each do |value|
      double_array_trie.set_column_value(value, column_name, value)
    end
  end
rescue LoadError
end

begin
  require 'localmemcache'

  LocalMemCache.drop(:namespace => "write-many-small-items", :force => true)
  mem_cache = LocalMemCache.new(:namespace => "write-many-small-items")
  item("Localmemcache: file") do
    values.each do |value|
      mem_cache[value] = value
    end
  end
rescue LoadError
end

begin
  require 'tokyocabinet'

  tc_hash_memory = TokyoCabinet::ADB::new
  tc_hash_memory.open("*#bnum=#{n}#mode=wct#xmsiz=0")
  item("TC: Hash: memory") do
    values.each do |value|
      tc_hash_memory.put(value, value)
    end
  end

  tc_tree_memory = TokyoCabinet::ADB::new
  tc_tree_memory.open("+#bnum=#{n}#mode=wct#xmsiz=0")
  item("TC: Tree: memory") do
    values.each do |value|
      tc_tree_memory.put(value, value)
    end
  end

  hash_file = Tempfile.new(["tc-hash", ".tch"])
  tc_hash_file = TokyoCabinet::ADB::new
  tc_hash_file.open("#{hash_file.path}#bnum=#{n}#mode=wct#xmsiz=0")
  item("TC: Hash: file") do
    values.each do |value|
      tc_hash_file.put(value, value)
    end
  end

  tree_file = Tempfile.new(["tc-tree", ".tcb"])
  tc_tree_file = TokyoCabinet::ADB::new
  tc_tree_file.open("#{tree_file.path}#bnum=#{n}#mode=wct#xmsiz=0")
  item("TC: Tree: file") do
    values.each do |value|
      tc_tree_file.put(value, value)
    end
  end
rescue LoadError
end

report(Integer(ARGV[0] || 0))
