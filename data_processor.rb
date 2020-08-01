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
    @prevDate = "N/A"
    @twelveMonthsAttendance = 0
  end

  def set_data(date, attendance)
    @date = date == "*" ? "*" : Date.strptime(date, "%m/%d/%Y")
    @attendance = attendance == "*" ? "*" : Integer(attendance)
  end

  def set_prev_date(prevDate)
    @prevDate = prevDate
  end

  def add_to_twelve_months(newAttendance)
    @twelveMonthsAttendance += newAttendance
  end

  attr_reader :date
  attr_reader :attendance
  attr_reader :prevDate
  attr_reader :twelveMonthsAttendance
end

# pr
def prepare_data(allCSVs)
  formattedData = Hash.new { |hash, key| hash[key] = Hash.new { |h, k| h[k] = ConYear.new } }
  actualOutput = Hash.new { |hash, key| hash[key] = Array.new() }
  minYear = 3000
  maxYear = 0

  allCSVs.each do |currCon|
    conName = currCon[0][0]
    
    actualOutput[conName + '-date'] << (conName + '-date')
    actualOutput[conName + '-attendance'] << conName
    
    currCon.each do |currYear|
      next unless currYear[0].is_i?

      unless currYear[1] == "*" || currYear[2] == "*"
        currDate = Date.strptime(currYear[1], "%m/%d/%Y")
        currDateInt = Integer(currDate.strftime("%j"), 10) - 1
        currDateYear = Integer(currDate.strftime("%Y"))
        minYear = (currDateYear < minYear ? currDateYear : minYear)
        maxYear = (currDateYear > maxYear ? currDateYear : maxYear)
        currDateInt = Date.gregorian_leap? currDateYear ? currDateYear + currDateInt.to_f / 366 : currDateYear + currDateInt.to_f / 365

        actualOutput[conName + '-date'] << currDateInt
        actualOutput[conName + '-attendance'] << Integer(currYear[2])
      end

      formattedData[conName][Integer(currYear[0])].set_data(currYear[1], currYear[2])
    end
  end

  maxYear += 1
  actualOutput['minYear'] = minYear
  actualOutput['maxYear'] = maxYear

  formattedData.each do |conName, conYears|
    conYears.to_a.each_with_index do |arr, i|
      if i == 0
        prevDate = arr[1].date
        prevDate = prevDate - Date.gregorian_leap? arr[0] ? 366 : 365
        formattedData[conName][arr[0]].set_prev_date prevDate
      else
        prevDate = formattedData[conName][arr[0] - 1].date
        if prevDate == "*" || prevDate == "N/A"
          prevDate = arr[1].date
          prevDate = prevDate - Date.gregorian_leap? arr[0] ? 366 : 365
        end
        formattedData[conName][arr[0]].set_prev_date prevDate
      end
    end
  end

  formattedData.each do |conName, conYears|
    conYears.to_a.each_with_index do |arr, i|
      if i == 0
        prevDate = arr[1].date
        prevDate = prevDate - Date.gregorian_leap? arr[0] ? 366 : 365
        formattedData[conName][arr[0]].set_prev_date prevDate
      else
        prevDate = formattedData[conName][arr[0] - 1].date
        if prevDate == "*" || prevDate == "N/A"
          prevDate = arr[1].date
          prevDate = prevDate - Date.gregorian_leap? arr[0] ? 366 : 365
        end
        formattedData[conName][arr[0]].set_prev_date prevDate
      end
    end
  end

  formattedData.each do |currConName, currConYears|
    currConYears.each do |currYear, currSpecificData|
      formattedData.each do |otherConName, otherConYears|
        next if currConName == otherConName

        competingAttendance = 0

        otherSpecificData = formattedData[otherConName][currYear]
        unless otherSpecificData.date == "*" || otherSpecificData.date == "N/A" || otherSpecificData.attendance == "*" || otherSpecificData.attendance == 0
          if otherSpecificData.date < currSpecificData.date && otherSpecificData.date > currSpecificData.prevDate
            competingAttendance += otherSpecificData.attendance 
          end
        end
        
        otherSpecificData = formattedData[otherConName][currYear - 1]
        unless otherSpecificData.date == "*" || otherSpecificData.date == "N/A" || otherSpecificData.attendance == "*" || otherSpecificData.attendance == 0
          if otherSpecificData.date <= currSpecificData.date && otherSpecificData.date > currSpecificData.prevDate
            competingAttendance += otherSpecificData.attendance 
          end    
        end

        formattedData[currConName][currYear].add_to_twelve_months competingAttendance
      end
    end
  end

  return formattedData, actualOutput
end

def get_max_attendances(formattedData)
  maxAttendances = Hash.new { |hash, key| hash[key] = 0 }

  formattedData.each do |conName, conYears|
    conYears.each do |year, specificData|
      next if specificData.date == "*" || specificData.date == "N/A" || specificData.attendance == "*" || specificData.attendance == 0

      maxAttendances[conName] = specificData.attendance if specificData.attendance > maxAttendances[conName]
    end
  end

  maxAttendances
end

def generate_calendar_year_data(formattedData, actualOutput)
  totalsForYear = Hash.new { |hash, key| hash[key] = 0.0 }
  formattedData.each do |conName, conYears|
    conYears.each do |year, specificData|
      next if specificData.date == "*" || specificData.date == "N/A" || specificData.attendance == "*" || specificData.attendance == 0

      totalsForYear[year] += specificData.attendance
    end
  end

  formattedData.each do |conName, conYears|
    actualOutput[conName + '-calYear'] << conName
    conYears.each do |year, specificData|
      next if specificData.date == "*" || specificData.date == "N/A" || specificData.attendance == "*" || specificData.attendance == 0

      actualOutput[conName + '-calYear'] << specificData.attendance / totalsForYear[year]
    end
  end

  actualOutput
end

def generate_twelve_months_data(attendances_by_datesformattedData, actualOutput)
  formattedData.each do |conName, conYears|
    actualOutput[conName + '-twelveMonths'] << conName
    conYears.each do |year, specificData|
      next if specificData.date == "*" || specificData.date == "N/A" || specificData.attendance == "*" || specificData.attendance == 0

      actualOutput[conName + '-twelveMonths'] << specificData.attendance / (specificData.twelveMonthsAttendance + specificData.attendance)
    end
  end

  actualOutput
end

allCSVs = Array.new

Dir.foreach('raw_data') do |filename|
  next if filename.start_with? "."
  allCSVs << CSV.read("raw_data/" + filename)
end

formattedData, actualOutput = prepare_data allCSVs

maxAttendances = get_max_attendances formattedData
sortedConNames = (maxAttendances.sort_by { |k, v| -v }).map { |n| n[0] }
actualOutput["sortOrder"] = sortedConNames

actualOutput = generate_calendar_year_data(formattedData, actualOutput)
actualOutput = generate_twelve_months_data(formattedData, actualOutput)

Dir.chdir('processed_data')

File.open("viz_data.json", "w") do |fout|
   fout.syswrite JSON.pretty_generate(actualOutput)
end
