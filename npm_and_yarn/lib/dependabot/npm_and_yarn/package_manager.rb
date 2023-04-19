# frozen_string_literal: true

module Dependabot
  module NpmAndYarn
    class PackageManager
      def initialize(package_json)
        @package_json = package_json
      end

      def setup(name)
        locked_version = locked_version(name)
        return unless locked_version

        _, process = Open3.capture2e("corepack", "prepare", "#{name}@#{locked_version}", "--activate")

        # In firewalled environments, we may not be able to download & activate
        # the locked version. In that case, let corepack choose the global
        # version from now on without trying to download or activate the locked
        # version.
        unless process.success?
          ENV["COREPACK_ENABLE_PROJECT_SPEC"] = "0"
          return
        end

        locked_version
      end

      def locked_version(name)
        locked = @package_json.fetch("packageManager", nil)
        return unless locked

        version_match = locked.match(/#{name}@(?<version>\d+.\d+.\d+)/)
        version_match&.named_captures&.fetch("version", nil)
      end
    end
  end
end
