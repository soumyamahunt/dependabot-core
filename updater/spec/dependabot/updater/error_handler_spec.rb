# typed: false
# frozen_string_literal: true

require "spec_helper"

require "dependabot/dependency"
require "dependabot/dependency_group"
require "dependabot/job"
require "dependabot/service"
require "dependabot/updater/error_handler"

RSpec.describe Dependabot::Updater::ErrorHandler do
  subject(:error_handler) do
    described_class.new(
      service: mock_service,
      job: mock_job
    )
  end

  let(:mock_service) do
    instance_double(Dependabot::Service)
  end

  let(:mock_job) do
    instance_double(Dependabot::Job)
  end

  describe "#handle_dependency_error" do
    let(:dependency) do
      instance_double(Dependabot::Dependency, name: "broken-biscuits")
    end

    let(:handle_dependency_error) do
      error_handler.handle_dependency_error(error: error, dependency: dependency)
    end

    context "with a handled known error" do
      let(:error) do
        Dependabot::DependencyFileNotResolvable.new("The file is full of bees")
      end

      it "records the error with the service and logs it out" do
        expect(mock_service).to receive(:record_update_job_error).with(
          error_type: "dependency_file_not_resolvable",
          error_details: { message: "The file is full of bees" },
          dependency: dependency
        )

        expect(Dependabot.logger).to receive(:info).with(
          a_string_starting_with("Handled error whilst updating broken-biscuits:")
        )

        handle_dependency_error
      end
    end

    context "with a handled unknown error" do
      let(:error) do
        StandardError.new("There are bees everywhere").tap do |err|
          err.set_backtrace ["bees.rb:5:in `buzz`"]
        end
      end

      it "records the error with the service, logs the backtrace and captures the exception" do
        expect(mock_service).to receive(:record_update_job_error).with(
          error_type: "unknown_error",
          error_details: nil,
          dependency: dependency
        )

        expect(mock_service).to receive(:capture_exception).with(
          error: error,
          job: mock_job,
          dependency: dependency,
          dependency_group: nil
        )

        expect(Dependabot.logger).to receive(:error).with(
          "Error processing broken-biscuits (StandardError)"
        )
        expect(Dependabot.logger).to receive(:error).with(
          "There are bees everywhere"
        )
        expect(Dependabot.logger).to receive(:error).with(
          "bees.rb:5:in `buzz`"
        )

        handle_dependency_error
      end
    end

    context "with a job-halting error" do
      let(:error) do
        Dependabot::OutOfDisk.new("The disk is full of bees")
      end

      it "re-raises the error" do
        expect { handle_dependency_error }.to raise_error(error)
      end
    end

    context "with a subprocess failure error" do
      let(:error_context) do
        { bumblebees: "many", honeybees: "few", wasps: "none", fingerprint: "123456789" }
      end

      let(:error) do
        Dependabot::SharedHelpers::HelperSubprocessFailed.new(message: "the kernal is full of bees",
                                                              error_context: error_context).tap do |err|
          err.set_backtrace ["****** ERROR 8335 -- 101"]
        end
      end

      it "records the error with the service and logs the backtrace" do
        expect(mock_service).to receive(:record_update_job_error).with(
          error_type: "unknown_error",
          error_details: nil,
          dependency: dependency
        )

        expect(mock_service).to receive(:capture_exception)

        expect(Dependabot.logger).to receive(:error).with(
          "Error processing broken-biscuits (Dependabot::SharedHelpers::HelperSubprocessFailed)"
        )
        expect(Dependabot.logger).to receive(:error).with(
          "the kernal is full of bees"
        )
        expect(Dependabot.logger).to receive(:error).with(
          "****** ERROR 8335 -- 101"
        )

        handle_dependency_error
      end

      it "sanitizes the error and captures it" do
        allow(Dependabot.logger).to receive(:error)
        allow(mock_service).to receive(:record_update_job_error)
        expect(mock_service).to receive(:capture_exception).with(
          error: an_instance_of(Dependabot::Updater::SubprocessFailed), job: mock_job
        ) do |args|
          expect(args[:error].message)
            .to eq('Subprocess ["123456789"] failed to run. Check the job logs for error messages')
          expect(args[:error].raven_context)
            .to eq(fingerprint: ["123456789"],
                   extra: {
                     bumblebees: "many", honeybees: "few", wasps: "none"
                   })
        end

        handle_dependency_error
      end
    end
  end

  describe "handle_job_error" do
    let(:handle_job_error) do
      error_handler.handle_job_error(error: error)
    end

    context "with a handled known error" do
      let(:error) do
        Dependabot::DependencyFileNotResolvable.new("The file is full of bees")
      end

      it "records the error with the service and logs it out" do
        expect(mock_service).to receive(:record_update_job_error).with(
          error_type: "dependency_file_not_resolvable",
          error_details: { message: "The file is full of bees" }
        )

        expect(Dependabot.logger).to receive(:info).with(
          a_string_starting_with("Handled error whilst processing job:")
        )

        handle_job_error
      end
    end

    context "with a handled unknown error" do
      let(:error) do
        StandardError.new("There are bees everywhere").tap do |err|
          err.set_backtrace ["bees.rb:5:in `buzz`"]
        end
      end

      it "records the error with the service, logs the backtrace and captures the exception" do
        expect(mock_service).to receive(:record_update_job_error).with(
          error_type: "unknown_error",
          error_details: nil
        )

        expect(mock_service).to receive(:capture_exception).with(
          error: error,
          job: mock_job,
          dependency: nil,
          dependency_group: nil
        )

        expect(Dependabot.logger).to receive(:error).with(
          "Error processing job (StandardError)"
        )
        expect(Dependabot.logger).to receive(:error).with(
          "There are bees everywhere"
        )
        expect(Dependabot.logger).to receive(:error).with(
          "bees.rb:5:in `buzz`"
        )

        handle_job_error
      end
    end

    context "with a job-halting error" do
      let(:error) do
        Dependabot::OutOfDisk.new("The disk is full of bees")
      end

      it "re-raises the error" do
        expect { handle_job_error }.to raise_error(error)
      end
    end
  end
end
