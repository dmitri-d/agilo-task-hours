#! /usr/bin/ruby
# === Examples
#   command line utility to set the number of remaining hours on a task.
#     hours -u username:password -t 3145 4
#
# === Usage
#   hours [options] remaining hours
#
#   For help use: hours -h
#
# === Options
#   -h, --help          Displays help message
#   -u, --user          username and password, separated with a ':'
#   -t, --task          task id

require 'rubygems'
require 'httpclient'
require 'nokogiri'
require 'cgi'
require 'optparse'
require 'rdoc/usage'

AGILO_URL = 'http://mgmt1.rhq.lab.eng.bos.redhat.com:8001/web'

class AgiloTaskHours
  attr_reader :options

  def initialize(arguments, stdin)
    @arguments = arguments
    @stdin = stdin    
    @options = {}
  end

  def run
    if parsed_options? && arguments_valid?  
      process_command
    else
      output_usage
    end
      
  end
  
  protected
  
    def parsed_options?
      opts = OptionParser.new do |opts|
        opts.on('-h', '--help') { output_help }    
        
        @options[:username] = ""  
        @options[:password] = ""
        opts.on('-u', '--user auth') do |auth|        
          credentials = auth.split(":")
          @options[:username] = credentials[0]
          @options[:password] = credentials[1]
        end
      
        @options[:ticket] = ""
        opts.on('-t', '--ticket ticket') do |ticket|
          @options[:ticket] = ticket
        end
      end
  
      opts.parse!(@arguments) rescue return false

      @options[:time_remaining] = @arguments.last      
      true
    end

    def arguments_valid?
      true if @arguments.length == 5 ||  @arguments.length == 1
    end
    
    def output_help
      RDoc::usage()
    end
    
    def output_usage
      RDoc::usage('usage')
    end

    def process_command
      client = HTTPClient.new
      client.set_auth(AGILO_URL, @options[:username], @options[:password])
      client.get_content("#{AGILO_URL}/login")

      page = Nokogiri::HTML(client.get_content("#{AGILO_URL}/ticket/#{@options[:ticket]}?pane=edit"))
      edit_ticket_form = page.css('form#propertyform')

      body_string = edit_ticket_form.css('input') \
        .select {|node| node['type'] != 'submit'} \
        .reject {|node| node['name'] == 'field_remaining_time'} \
        .reject {|node| node['type'] == 'radio' && node['checked'] != 'checked'} \
        .inject("") do |body, node|
        body << "&" if body != ""  
        body << "#{node['name']}=" << CGI.escape("#{node['value']}")
      end << "&field_remaining_time=#{@options[:time_remaining]}&submit=Submit+changes"

      puts client.post("#{AGILO_URL}/ticket/#{@options[:ticket]}", body=body_string).status
    end
end

AgiloTaskHours.new(ARGV, STDIN).run
