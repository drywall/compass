module Compass
  module Installers

    class Base

      include Compass::Actions

      attr_accessor :template_path, :target_path, :working_path
      attr_accessor :options
      attr_accessor :manifest
      attr_accessor :css_dir, :sass_dir, :images_dir, :javascripts_dir

      def initialize(template_path, target_path, options = {})
        @template_path = template_path
        @target_path = target_path
        @working_path = Dir.getwd
        @options = options
        @manifest = Manifest.new(manifest_file)
        self.logger = options[:logger]
        configure
      end

      def manifest_file
        @manifest_file ||= File.join(template_path, "manifest.rb")
      end

      # Initializes the project to work with compass
      def init
      end

      # Runs the installer.
      # Every installer must conform to the installation strategy of prepare, install, and then finalize.
      # A default implementation is provided for each step.
      def run(options = {})
        prepare
        install
        finalize unless options[:skip_finalization]
      end

      # The default configure method -- it sets up directories from the options
      # and corresponding default_* methods for those not found in the options hash.
      # It can be overridden it or augmented for reading config files,
      # prompting the user for more information, etc.
      def configure
        unless @configured
          [:css_dir, :sass_dir, :images_dir, :javascripts_dir].each do |opt|
            configure_option_with_default opt
          end
        end
      ensure
        @configured = true
      end

      # The default prepare method -- it is a no-op.
      # Generally you would create required directories, etc.
      def prepare
      end

      def configure_option_with_default(opt)
        value = options[opt]
        value ||= begin
          default_method = "default_#{opt}".to_sym
          send(default_method) if respond_to?(default_method)
        end
        send("#{opt}=", value)
      end
  
      # The default install method. Calls install_<type> methods in the order specified by the manifest.
      def install
        manifest.each do |entry|
          send("install_#{entry.type}", entry.from, entry.to, entry.options)
        end
      end

      # The default finalize method -- it is a no-op.
      # This could print out a message or something.
      def finalize
      end

      def compilation_required?
        false
      end

      def install_stylesheet(from, to, options)
        copy templatize(from), targetize("#{sass_dir}/#{to}")
      end

      def install_image(from, to, options)
        copy templatize(from), targetize("#{images_dir}/#{to}")
      end

      def install_script(from, to, options)
        copy templatize(from), targetize("#{javascripts_dir}/#{to}")
      end

      def install_file(from, to, options)
        copy templatize(from), targetize(to)
      end

      # returns an absolute path given a path relative to the current installation target.
      # Paths can use unix style "/" and will be corrected for the current platform.
      def targetize(path)
        File.join(target_path, separate(path))
      end

      # returns an absolute path given a path relative to the current template.
      # Paths can use unix style "/" and will be corrected for the current platform.
      def templatize(path)
        File.join(template_path, separate(path))
      end

      # Write paths like we're on unix and then fix it
      def separate(path)
        path.gsub(%r{/}, File::SEPARATOR)
      end

      def stylesheet_links
        html = "<head>\n"
        manifest.each_stylesheet do |stylesheet|
          media = if stylesheet.options[:media]
            %Q{ media="#{stylesheet.options[:media]}"}
          end
          ss_line = %Q{  <link href="/stylesheets/#{stylesheet.to.sub(/\.sass$/,'.css')}"#{media} rel="stylesheet" type="text/css" />}
          if stylesheet.options[:ie]
            ss_line = "  <!--[if IE]>\n    #{ss_line}\n  <![endif]-->"
          end
          html << ss_line + "\n"
        end
        html << "</head>"
      end
    end
  end
end
