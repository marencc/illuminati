#! /usr/bin/env ruby

$:.unshift(File.join(File.dirname(__FILE__), "lib"))

require 'illuminati'

class ConfigFileMaker
  def self.make data, flowcell, output_file
    cf = ConfigFileMaker.new(data, flowcell)
    cf.output(output_file)
  end

  def initialize data, flowcell
    @rows = data
    @input_dir = flowcell.unaligned_dir
    @flowcell_id = flowcell.flowcell_id
  end

  def combine_rows rows
    combined_rows = Array.new
    current_row = 0
    combined_rows << rows[current_row]
    rows[1..-1].each do |row|
      # puts row.to_s
      combo_row = combined_rows[current_row]
      if row_equal combo_row, row
        combo_row[:number] = combo_row[:number].to_s << row[:number]
        combined_rows[current_row] = combo_row
      else
        combined_rows << row
        current_row += 1
      end
    end
    combined_rows
  end

  def output output_file
    template = ERB.new File.new("#{SCRIPT_PATH}/config_template_1_8.erb").read, nil, "%<>"
    output = template.result(binding)

    puts "config file"

    if output_file
      puts "outputing config file to #{output_file}"
      File.open(output_file, 'w') do |file|
        file << output
      end
    else
      puts output
    end
  end
end #ConfigFile
class SampleSheetMaker

  def self.make data, output_file
    ss = SampleSheetMaker.new data
    ss.output output_file
  end

  def initialize data
    @rows = data
  end

  def output output_file
    sample_sheet =  ["FCID", "Lane", "SampleID",
                     "SampleRef", "index", "Description",
                     "Control", "Recipe", "Operator",
                     "SampleProject"].join(",")
    sample_sheet += "\n"

    @rows.each do |row|
      data = [:fcid, :lane, :sample_id,
              :sample_ref, :index, :description,
              :control, :recipe, :operator,
              :sample_project].collect {|field| row[field]}
      sample_sheet +=  data.join(",")
      sample_sheet += "\n"
    end

    puts ""
    puts sample_sheet
    if output_file
      path = File.expand_path(output_file)
      puts "Creating SampleSheet.csv at #{path}"
      File.open(path, 'w') do |file|
        file << sample_sheet
      end
    end
  end
end # SampleSheet

class BarcodeFileMaker
  def self.make multiplex_data, flowcell
    rtn = []
    (1..8).each do |lane|
      barcodes_for_lane = multiplex_data.select {|data| data[:lane] == lane and data[:custom_barcode]}
      if !barcodes_for_lane.empty?
        write_barcodes barcodes_for_lane, flowcell.custom_barcode_path(lane)
        rtn << lane
      end
    end
    rtn
  end

  def self.write_barcodes barcode_data, output_file
    File.open(output_file, 'w') do |file|
      barcode_data.each do |data|
        file << data[:custom_barcode] << "\t" << data[:custom_barcode] << "\n"
      end
    end
  end

end # BarcodeFile


if __FILE__ == $0

flowcell_id = ARGV[0]

config_output_file = ARGV[1]
sample_sheet_output_file = ARGV[2]

if flowcell_id
  puts "Flowcell ID: #{flowcell_id}"
else
  puts "ERROR: no flow cell ID provided"
  exit
end

lims = LimsData.new flowcell_id
flowcell = FlowcellData.new(flowcell_id)

lims_lanes = lims.lanes

multiplex_data = MultiplexData.new flowcell.flowcell_id, flowcell.base_dir

multplex_rows = multiplex_data.add_to(lims_lanes.clone)
sample_sheet = SampleSheetMaker.make multplex_rows, sample_sheet_output_file

rows = lims.lanes_combined
config_file = ConfigFileMaker.make rows, flowcell, config_output_file

lanes_with_barcodes = BarcodeFileMaker.make multiplex_data.get_multiplex_data, flowcell

if !lanes_with_barcodes.empty?
  puts "Custom Barcode files made for lanes #{lanes_with_barcodes.join(", ")}"
else
  puts "No custom Barcodes found"
end
end

