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
    def is_date_ish?
      /\A\d{1,2}\/\d{1,2}\/\d{4}\z/ === self
    end
end

class SortaDate
  include Comparable

  def initialize(year=0, day=0)
    if year.is_a?(String)
      date = Date.strptime(year, "%m/%d/%Y")
      @year = Integer(date.strftime("%Y"))
      @day = Integer(date.strftime("%j"), 10) - 1
    else
      @year = year
      @day = day
    end
  end

  def is_leap_year?
    Date.gregorian_leap?(@year)
  end

  def to_f
    @year + (@day.to_f / (self.is_leap_year? ? 366 : 365))
  end

  def to_i
    @year
  end

  def <=>(otherDate)
    retval = @year <=> otherDate.year
    if retval == 0
      @day <=> otherDate.day
    else
      retval
    end
  end

  def +(time)
    days = (time * 365).to_i

    retval = SortaDate.new(@year, @day)
    retval.day += days
    
    while retval.day >= (retval.is_leap_year? ? 366 : 365)
      retval.day -= (retval.is_leap_year? ? 366 : 365)
      retval.year += 1
    end

    retval
  end

  def -(time)
    if time.is_a?(SortaDate)
      days = (@year - time.year) * 365
      days += @day - time.day
      days.to_f / 365
    else
      days = (time * 365).to_i

      retval = SortaDate.new(@year, @day)
      retval.day -= days
      
      while retval.day < 0
        retval.year -= 1
        retval.day += (retval.is_leap_year? ? 366 : 365)
      end

      retval
    end
  end

  attr_accessor :year
  attr_accessor :day
end

class ConYear
  def initialize(attendance=0, dateYear=0, dateInt=0)
    @date = SortaDate.new(dateYear, dateInt)
    @prevDate = @date - 1.025
    @attendance = Integer(attendance)
    @prevCons = Array.new
  end

  def set_prev_date(dateYear=0, dateInt=0)
    if dateYear.is_a?(SortaDate)
      newDate = dateYear
    else
      newDate = SortaDate.new(dateYear, dateInt)
    end
    
    if newDate > @prevDate
      @prevDate = newDate
      @prevCons.select! {|x| x.date > @prevDate and x.date <= @date}
    end
  end

  def add_to_previous_cons(newConYear)
    @prevCons << newConYear if newConYear.date > @prevDate and newConYear.date <= @date
  end

  def get_market_share_comparison
    @prevCons.inject(0){ |sum, x| sum + x.attendance }
  end

  attr_reader :date
  attr_reader :attendance
  attr_reader :prevDate
  attr_reader :prevCons
end

def prepare_data(allCSVs)
  formattedData = Hash.new { |hash, key| hash[key] = Array.new }
  actualOutput = Hash.new { |hash, key| hash[key] = Array.new }
  minYear = Float::INFINITY
  maxYear = -Float::INFINITY 

  allCSVs.each do |currCon|
    conName = currCon[0][0]
    
    currCon.each do |currYear|
      next unless currYear[0].is_date_ish?

      currConYear = ConYear.new(currYear[1], currYear[0])

      minYear = (currConYear.date.to_i < minYear ? currConYear.date.to_i : minYear)
      maxYear = (currConYear.date.to_i > maxYear ? currConYear.date.to_i : maxYear)

      formattedData[conName] << currConYear
    end
  end

  maxYear += 1
  actualOutput['minYear'] = minYear
  actualOutput['maxYear'] = maxYear

  maxAttendances = get_max_attendances formattedData
  sortedConNames = (maxAttendances.sort_by { |k, v| -v }).map { |n| n[0] }
  actualOutput["sortOrder"] = sortedConNames

  formattedData.each do |conName, conYears|
    conYears.each_with_index do |currYear, i|
      currYear.set_prev_date formattedData[conName][i - 1].date unless i == 0
    end
  end

  formattedData.each do |conName, conYears|
    conYears.each do |currYear|
      formattedData.each do |otherConName, otherConYears|
        otherConYears.each{ |x| currYear.add_to_previous_cons x }
      end
    end
  end

  formattedData.each do |conName, conYears|
    actualOutput[conName + '-date'] << (conName + '-date')
    actualOutput[conName + '-attendance'] << conName
    actualOutput[conName + '-twelveMonths'] << conName
    
    conYears.each_with_index do |currYear, i|
      if i > 0 and currYear.date - formattedData[conName][i - 1].date > 1.5
        medianTime = (currYear.date - formattedData[conName][i - 1].date) / 2
        actualOutput[conName + '-date'] << (currYear.date - medianTime).to_f
        actualOutput[conName + '-attendance'] << "*"
        actualOutput[conName + '-twelveMonths'] << "*"
      end
      actualOutput[conName + '-date'] << currYear.date.to_f
      actualOutput[conName + '-attendance'] << currYear.attendance
      actualOutput[conName + '-twelveMonths'] << (currYear.attendance.to_f / currYear.get_market_share_comparison)
    end
  end

  actualOutput
end

def get_max_attendances(formattedData)
  maxAttendances = Hash.new { |hash, key| hash[key] = -Float::INFINITY }

  formattedData.each do |conName, conYears|
    conYears.each do |currYear|
      maxAttendances[conName] = currYear.attendance if currYear.attendance > maxAttendances[conName]
    end
  end

  maxAttendances
end

allCSVs = Array.new

Dir.foreach('raw_data') do |filename|
  next if filename.start_with? "."
  allCSVs << CSV.read("raw_data/" + filename)
end

actualOutput = prepare_data allCSVs

File.open("viz_data.json", "w") do |fout|
   fout.syswrite JSON.pretty_generate(actualOutput)
end
