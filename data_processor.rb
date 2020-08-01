#!/usr/bin/ruby

##
# data_processor.rb - Processes raw furry convention attendance data into useful csv's
# created by Huehuecóyotl
#
# USAGE: "ruby data_processor.rb"

require 'csv'
require 'date'
require 'json'

class String
    def is_i?
       /\A[-+]?\d+\z/ === self
    end
end

class ConYear
  def initialize
    @date = "N/A"
    @attendance = 0
  end

  def set_data(date, attendance)
    @date = date == "*" ? "*" : Date.strptime(date, "%m/%d/%Y")
    @attendance = attendance == "*" ? "*" : Integer(attendance)
  end

  attr_reader :date
  attr_reader :attendance
end

# pr
def prettify_data(all_csvs)
  pretty_data = Hash.new { |hash, key| hash[key] = Hash.new { |h, k| h[k] = ConYear.new } }
  actual_output = Hash.new { |hash, key| hash[key] = Array.new() }

  all_csvs.each do |curr_con|
    curr_con_name = curr_con[0][0]
    curr_con.each do |curr_year|
      next unless curr_year[0].is_i?

      unless curr_year[1] == "*" || curr_year[2] == "*"
        curr_date = Date.strptime(curr_year[1], "%m/%d/%Y")
        curr_date_int = Integer(curr_date.strftime("%j"), 10) - 1
        curr_date_year = Integer(curr_date.strftime("%Y"))
        curr_date_int = Date.gregorian_leap?(curr_date_year) ? curr_date_year + (curr_date_int / 366) : curr_date_year + (curr_date_int / 365)

        actual_output[curr_con_name + '-date'] << curr_date_int
        actual_output[curr_con_name + '-attendance'] << Integer(curr_year[2])
      end

      pretty_data[curr_con_name][Integer(curr_year[0])].set_data(curr_year[1], curr_year[2])
    end
  end

  return pretty_data, actual_output
end

def get_max_attendances(pretty_csvs)
  max_attendances = Hash.new { |hash, key| hash[key] = 0 }
  min_years = Hash.new { |hash, key| hash[key] = 3000 }
  max_years = Hash.new { |hash, key| hash[key] = 0 }
  min_year = 3000
  max_year = 0

  pretty_csvs.each do |con_name, con_years|
    con_years.each do |year, specific_data|
      if year < min_years[con_name]
        min_years[con_name] = year
        min_year = year if year < min_year
      end
      
      if year > max_years[con_name]
        max_years[con_name] = year
        max_year = year if year > max_year
      end

      next if specific_data.attendance == "*"

      max_attendances[con_name] = specific_data.attendance if specific_data.attendance > max_attendances[con_name]
    end
  end

  return max_attendances, max_years, max_year, min_years, min_year
end

def generate_attendance_csv(pretty_csvs, sorted_con_names, max_years, max_year, min_years, min_year)
  attendances = Array.new
  attendances << ["YEAR"]
  attendances[0].concat (min_year .. max_year).to_a

  dates = Array.new
  dates << ["YEAR"]
  dates[0].concat (min_year .. max_year).to_a

  sorted_con_names.each do |con_name|
    curr_row_a = Array.new
    curr_row_a << con_name

    curr_row_d = Array.new
    curr_row_d << con_name
    
    (min_year .. min_years[con_name] - 1).each do |x|
      curr_row_a << 0
      curr_row_d << "N/A"
    end
    
    pretty_csvs[con_name].each do |year, specific_data|
      curr_row_a << specific_data.attendance
      curr_row_d << specific_data.date
    end

    (max_years[con_name] .. max_year - 1).each do |x|
      curr_row_a << 0 
      curr_row_d << "N/A"
    end

    attendances << curr_row_a
    dates << curr_row_d
  end

  return attendances.transpose, dates.transpose
end

def generate_calYear_csv(attendances, actual_output, pretty_csvs, sorted_con_names, max_years, max_year, min_years, min_year)
  calYear = Array.new
  calYear << ["YEAR"]
  calYear[0].concat (min_year .. max_year).to_a

  totals_for_year = Hash.new { |hash, key| hash[key] = 0.0 }
  (min_year .. max_year).each do |year|
    attendances[year - min_year + 1].each_with_index do |attendance, i|
      next if i == 0 or attendance == "*"

      totals_for_year[year] += attendance
    end
  end

  sorted_con_names.each do |con_name|
    curr_row = Array.new
    curr_row << con_name
    
    (min_year .. min_years[con_name] - 1).each { |x| curr_row << 0.0 }
    
    pretty_csvs[con_name].each do |year, specific_data|
      actual_output[con_name + '-calYear'] << (specific_data.attendance / totals_for_year[year]) unless (specific_data.attendance == "*")
      curr_row << ((specific_data.attendance == "*") ? "*" : (specific_data.attendance / totals_for_year[year]))
    end

    (max_years[con_name] .. max_year - 1).each { |x| curr_row << 0.0 }

    calYear << curr_row
  end

  return calYear.transpose, actual_output
end

def generate_by_date_attendances(attendance_csv, dates, sorted_con_names, pretty_csvs)
  attendance_by_date = Array.new
  attendance_by_date << ["DATE"]
  everything_but = Array.new
  dates_t = dates.transpose

  dates.each_with_index do |year, i|
    next if i == 0

    year.each_with_index do |date, j|
      next if j == 0

      everything_but << date if date != "N/A" and date != "*"
    end
  end

  attendance_by_date[0].concat everything_but.sort

  sorted_con_names.each_with_index do |con_name, i|
    curr_row = Array.new
    curr_row << con_name
    
    attendance_by_date[0].each_with_index do |x, j|
      next if j == 0

      first_before_or_is = nil
      index_of_first = 0
      dates_t[i + 1].each_with_index do |date, k|
        next if k == 0
        next if date == "*" or date == "N/A"

        first_before_or_is = date if date <= x
        index_of_first = k if date <= x
      end

      if first_before_or_is == nil
        curr_row << 0
        next
      end

      if first_before_or_is + 365 < x
        curr_row << 0
        next
      end

      curr_row << attendance_csv[index_of_first][i+1]
    end

    attendance_by_date << curr_row
  end
  attendance_by_date.transpose
end

def generate_twelveMonths_csv(attendances_by_dates, actual_output, pretty_csvs, sorted_con_names, max_years, max_year, min_years, min_year)
  twelveMonths = Array.new
  twelveMonths << ["YEAR"]
  twelveMonths[0].concat (min_year .. max_year).to_a

  totals_for_date = Hash.new { |hash, key| hash[key] = 0.0 }
  attendances_by_dates.each_with_index do |date, i|
    next if i == 0

    totals_for_date[date[0]] = 0.0
    date.each_with_index do |attendance, i|
      next if i == 0 or attendance == "*"

      totals_for_date[date[0]] += attendance
    end
  end

  sorted_con_names.each do |con_name|
    curr_row = Array.new
    curr_row << con_name
    
    (min_year .. min_years[con_name] - 1).each { |x| curr_row << 0.0 }
    
    pretty_csvs[con_name].each do |year, specific_data|
      actual_output[con_name + '-twelveMonths'] << (specific_data.attendance / totals_for_date[specific_data.date]) unless (specific_data.attendance == "*")
      curr_row << ((specific_data.attendance == "*") ? "*" : (specific_data.attendance / totals_for_date[specific_data.date]))
    end

    (max_years[con_name] .. max_year - 1).each { |x| curr_row << 0.0 }

    twelveMonths << curr_row
  end

  return twelveMonths.transpose, actual_output
end

all_csvs = Array.new

Dir.foreach('raw_data') do |filename|
  next if filename.start_with? "."
  all_csvs << CSV.read("raw_data/" + filename)
end

pretty_csvs, actual_output = prettify_data all_csvs

max_attendances, max_years, max_year, min_years, min_year = get_max_attendances pretty_csvs
sorted_con_names = (max_attendances.sort_by { |k, v| -v }).map { |n| n[0] }

attendance_csv, dates = generate_attendance_csv(pretty_csvs, sorted_con_names, max_years, max_year, min_years, min_year)
calYear_csv = generate_calYear_csv(attendance_csv, actual_output, pretty_csvs, sorted_con_names, max_years, max_year, min_years, min_year)
attendance_by_date = generate_by_date_attendances(attendance_csv, dates, sorted_con_names, pretty_csvs)
twelveMonths_csv = generate_twelveMonths_csv(attendance_by_date, actual_output, pretty_csvs, sorted_con_names, max_years, max_year, min_years, min_year)

Dir.chdir('processed_data')

CSV.open("attendance.csv", "w") do |csv|
  attendance_csv.each { |x| csv << x }
end

CSV.open("calYear.csv", "w") do |csv|
  calYear_csv.each { |x| csv << x }
end

CSV.open("twelveMonths.csv", "w") do |csv|
  twelveMonths_csv.each { |x| csv << x }
end

File.open("all_data.json", "w") do |fout|
   fout.syswrite JSON.pretty_generate(actual_output)
end
