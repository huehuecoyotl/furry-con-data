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

class SortaDate   # expands the concept of Dates by adding logic helpful for how we handle calendar math with conventions
  include Comparable

  def initialize(year=0, day=0)
    if year.is_a?(String)   # When the only variable passed in is a string date
      date = Date.strptime(year, "%m/%d/%Y")
      @year = Integer(date.strftime("%Y"))
      @day = Integer(date.strftime("%j"), 10) - 1   # what number day was this in the year (between 0 and 364/365)
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

  def +(time)   # time is a (float) number of years
    # (Sorta; +1 isn't the same day in the next year, rather 365 days later, for consistencies' sake.
    # 365 day-long years works for my intentions assuming that conventions are always on weekends...
    # now that BLFC is during the week, this assumption may have unintended consequences I have not fully thought through yet)
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
    if time.is_a?(SortaDate)    # In this case, we're taking the difference between two dates in days
      days = (@year - time.year) * 365
      days += @day - time.day
      days.to_f / 365
    else                        # In this case, we're doing the opposite of +
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
    
    # in a convention's first year (or if there is an atypically large gap between years),
    # comparisons are made with a date 1.025 years ago instead of with the previous iteration,
    # which is a (very) rough estimate for how much time usually exists between convention years.
    # (1.025 years is approximately 1 year and 9 days).
    @prevDate = @date - 1.025

    @attendance = Integer(attendance)
    @prevAttendance = 0
    @prevCons = Array.new
  end

  # If a convention happened more recently than 1 year and 9 days ago
  # (for non-new conventions, this is expected),
  # set the previous date exactly
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

  def set_prev_attendance(attendeeCount)
    @prevAttendance = attendeeCount
  end

  # For comparison's sake, conventions that happen on the same weekend as each other are compared to each other by current year, not previous year
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

# TFF 2020 finished on March 1, 2020, and is currently the last convention in the dataset before COVID shutdowns began.
# I have chosen March 11, 2020 as the canonical start of COVID-19 pandemic shutdowns, as that was the day the NBA first began shutting down games.
BEGINNING_OF_COVID_SHUTDOWNS = SortaDate.new("3/11/2020")

# Megaplex 2021 began on August 5, 2021, and is currently the first convention in the dataset to hold a convention following the beginning of COVID shutdowns.
# With the reminder that this date does not represent the end of the COVID-19 pandemic, and that this date is used in this codebase to represent when market share measurements can begin being meaningful again
# I have chosen this date as the canonical end of COVID-19 pandemic shutdowns
END_OF_COVID_SHUTDOWNS = SortaDate.new("8/5/2021")

def prepare_data(allCSVs)
  # formattedData[convention-by-name] = [list of attendances by year]
  formattedData = Hash.new { |hash, key| hash[key] = Array.new }

  # actualOutput['minYear'] = year of first furry convention
  # actualOutput['maxYear'] = year of most recent furry convention
  # actualOutput['sortOrder'] = [list of convention names, sorted by max attendance ever]
  # actualOutput[convention-by-name + '-date'] = [list of named convention's dates (as floats)]
  # actualOutput[convention-by-name + '-attendance'] = [list of named convention's attendances]
  # actualOutput[convention-by-name + '-twelveMonths'] = [list of named convention's market shares]
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
      currYear.set_prev_attendance formattedData[conName][i - 1].attendance unless i == 0
    end
  end

  # This is hella unoptimized, but the dataset is not yet so big to make this painful.
  # (Attempts to add every convention-year pair to every other convention-year pair's set of conventions in the previous year.
  # The underlying classes filter out con-year pairs that aren't relevant to each other.)
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
    actualOutput[conName + '-growth'] << conName
    
    conYears.each_with_index do |currYear, i|
      # If there is a gap between iterations of a convention of more than 1.5 years, force the graph to display a discontinuity
      # (Believe it or not, this was already in the code before COVID-19. Woo, I guess.)
      if i > 0 and currYear.date - formattedData[conName][i - 1].date > 1.5
        medianTime = (currYear.date - formattedData[conName][i - 1].date) / 2
        actualOutput[conName + '-date'] << (currYear.date - medianTime).to_f
        actualOutput[conName + '-attendance'] << "*"
        actualOutput[conName + '-twelveMonths'] << "*"
        actualOutput[conName + '-growth'] << "*"
      end

      actualOutput[conName + '-date'] << currYear.date.to_f
      actualOutput[conName + '-attendance'] << currYear.attendance
      actualOutput[conName + '-growth'] << (currYear.attendance - currYear.prevAttendance).to_f / currYear.prevAttendance

      # Do not attempt to display a market share until after a year has passed from the end of covid shutdowns.
      if currYear.date > BEGINNING_OF_COVID_SHUTDOWNS and currYear.date < (END_OF_COVID_SHUTDOWNS + 1)
        actualOutput[conName + '-twelveMonths'] << "*"
      else
        actualOutput[conName + '-twelveMonths'] << (currYear.attendance.to_f / currYear.get_market_share_comparison)
      end
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
