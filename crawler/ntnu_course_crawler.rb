require 'thread'
require 'thwait'

require 'json'
require 'rest-client'
require 'nokogiri'
require 'pry'

class NtnuCourseCrawler

  DAYS = {
    "一" => 1,
    "二" => 2,
    "三" => 3,
    "四" => 4,
    "五" => 5,
    "六" => 6,
    "日" => 7,
  }

  def initialize year: current_year, term: current_term, update_progress: nil, after_each: nil, params: nil
    @url = "http://courseap.itc.ntnu.edu.tw/acadmOpenCourse/CofopdlCtrl"
    @syllabus_url = "http://courseap.itc.ntnu.edu.tw/acadmOpenCourse/SyllabusCtrl"

    @year = params && params["year"].to_i || year
    @term = params && params["term"].to_i || term
    @update_progress_proc = update_progress
    @after_each_proc = after_each
  end

  def courses
    @courses = []

    departments = JSON.parse(File.read('department.json'))
    done_departments_count = 0

    @threads = []

    departments.keys.each_with_index do |dep_code, index|
      sleep(1) until (
        @threads.delete_if { |t| !t.status };  # remove dead (ended) threads
        @threads.count < (ENV['MAX_THREADS'] || 25)
      )

      @threads << Thread.new do
        puts "#{dep_code}, #{index}"
        begin
          respond = RestClient.get @url, params: url_params_for_department(department: dep_code, year: @year-1911, term: @term)
          respond = JSON.parse(respond.to_s)
        rescue
          puts "Error on #{dep_code}! retry later..."
          sleep(1)
          redo
        end

        course_detail_threads = []

        @courses.concat(respond['List'])
        # respond['List'].each do |course|

          # course_detail_threads << Thread.new do

            # begin
            #   respond = RestClient.get @syllabus_url, :params => url_params_for_course(course)
            #   html = Nokogiri::HTML(respond.to_s)
            #   book_row = html.css('tr:contains("參考書目") css')
            #   course[:textbook] = book_row.last.text unless book_row.empty?
            # rescue Exception => e
            #   course[:textbook] = nil
            # end

            # @courses << course
          # end
        # end

        # ThreadsWait.all_waits(*course_detail_threads)

        done_departments_count += 1
        puts "(#{done_departments_count}/#{departments.count}) done #{dep_code}"
      end
    end
    ThreadsWait.all_waits(*@threads)

    if done_departments_count == departments.count

      File.open('courses.json', 'w') { |f| f.write(JSON.pretty_generate(normalize(@courses))) }
    end

  end

  private
    def url_params_for_department(department: department, year: nil, term: nil, language: 'chinese')
      {
        acadmYear: year,
        acadmTerm: term,
        deptCode: department,
        language: language,
        action: 'showGrid',
        start: 0,
        limit: 99999,
        page: 1
      }
    end

    def url_params_for_course(c)
      {
        year: c["acadm_year"],
        term: c["acadm_term"],
        courseCode: c["course_code"],
        courseGroup: c["course_group"],
        formS: c["form_s"],
        classes1: c["classes"],
        deptCode: c["dept_code"],
        deptGroup: c["dept_group"],
        language2: ""
      }
    end

    def current_year
      (Time.now.month.between?(1, 7) ? Time.now.year - 1 : Time.now.year)
    end

    def current_term
      (Time.now.month.between?(2, 7) ? 2 : 1)
    end

    def normalize(courses)
      courses.map do |course|
        # course["time_inf"] = '一 9-10 本部 音樂系演奏廳,五 9-10 本部 音樂系演奏廳,'
        course_days = []
        course_periods = []
        course_locations = []
        course["time_inf"].split(',').each do |time_info|
          time_info.match(/(?<d>[#{DAYS.keys.join}]) (?<p>[\d|\-]+) (?<loc>.+)/) do |m|
            ps = m[:p].split('-')
            _start = ps[0].to_i
            _end = ps[1].to_i
            (_start.._end).each do|p|
              course_days << m[:d]
              course_periods << p
              course_locations << m[:loc]
            end
          end
        end
        {
          year: course["acadm_year"],
          term: course["acadm_term"],
          name: course["chn_name"],
          code: "#{course["acadm_year"]}-#{course["acadm_term"]}-#{course["course_code"]}",
          credits: course["credit"].to_i,
          department: course["dept_chiabbr"],
          department_code: course["dept_code"],
          required: course["option_code"] == '必',
          lecturer: course["teacher"],
          day_1: course_days[0],
          day_2: course_days[1],
          day_3: course_days[2],
          day_4: course_days[3],
          day_5: course_days[4],
          day_6: course_days[5],
          day_7: course_days[6],
          day_8: course_days[7],
          day_9: course_days[8],
          period_1: course_periods[0],
          period_2: course_periods[1],
          period_3: course_periods[2],
          period_4: course_periods[3],
          period_5: course_periods[4],
          period_6: course_periods[5],
          period_7: course_periods[6],
          period_8: course_periods[7],
          period_9: course_periods[8],
          location_1: course_locations[0],
          location_2: course_locations[1],
          location_3: course_locations[2],
          location_4: course_locations[3],
          location_5: course_locations[4],
          location_6: course_locations[5],
          location_7: course_locations[6],
          location_8: course_locations[7],
          location_9: course_locations[8],
        }
      end
    end
end

crawler = NtnuCourseCrawler.new(year: 2014, term: 1)
crawler.courses
