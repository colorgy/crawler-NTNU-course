require 'json'
require 'rest_client'
require 'nokogiri'
require 'pry'

require 'thread'
require 'thwait'

require 'dotenv'
Dotenv.load

require 'sinatra'

url = "http://courseap.itc.ntnu.edu.tw/acadmOpenCourse/CofopdlCtrl"
syllabus_url = "http://courseap.itc.ntnu.edu.tw/acadmOpenCourse/SyllabusCtrl"

def url_params_for_department(department, year=103, term=2, language='chinese')
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

get '/' do

  error 401, { status: 'bad key' }.to_json if params['key'] != ENV['API_KEY']

  courses = []

  departments = JSON.parse(File.read('department.json'))
  done_departments_count = 0

  threads = []

  departments.keys.each_with_index do |dep_code, index|

    threads << Thread.new do
      begin
        respond = RestClient.get url, :params => url_params_for_department(dep_code)
        respond = JSON.parse(respond.to_s)
      rescue
        puts "Error on #{dep_code}! retry later..."
        sleep(1)
        redo
      end

      course_detial_threads = []

      respond['List'].each do |course|

        course_detial_threads << Thread.new do

          # begin
          #   respond = RestClient.get syllabus_url, :params => url_params_for_course(course)
          #   html = Nokogiri::HTML(respond.to_s)
          #   book_row = html.css('tr:contains("參考書目") css')
          #   course[:textbook] = book_row.last.text unless book_row.empty?
          # rescue Exception => e
          #   course[:textbook] = nil
          # end

          courses << course
        end
      end

      ThreadsWait.all_waits(*course_detial_threads)

      done_departments_count += 1
      puts "(#{done_departments_count}/#{departments.count}) done #{dep_code}"

      if done_departments_count == departments.count
        File.open('courses.json', 'w') { |f| f.write(JSON.pretty_generate(courses)) }
      end
    end
  end

  ThreadsWait.all_waits(*threads)

  puts 'done'
  { status: 'ok' }.to_json
end
