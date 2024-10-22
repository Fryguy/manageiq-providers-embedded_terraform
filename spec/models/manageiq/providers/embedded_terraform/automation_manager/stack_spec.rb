RSpec.describe ManageIQ::Providers::EmbeddedTerraform::AutomationManager::Stack do
  describe "#raw_status" do
    let(:stack) { FactoryBot.create(:terraform_stack, :miq_task => miq_task) }

    context "with a running deployment" do
      let(:miq_task) { FactoryBot.create(:miq_task, :state => "Running", :status => "Ok", :message => "process initiated") }

      it "returns a status that is running" do
        expect(stack.raw_status.completed?).to be_falsey
      end
    end

    context "with a successful deployment" do
      let(:miq_task) { FactoryBot.create(:miq_task, :state => "Finished", :status => "Ok", :message => "Task completed successfully") }

      it "returns a status that is completed" do
        expect(stack.raw_status.completed?).to be_truthy
      end
    end

    context "with a failed deployment" do
      let(:miq_task) { FactoryBot.create(:miq_task, :state => "Finished", :status => "Error", :message => "Failed to run template") }

      it "returns a status that is failed" do
        expect(stack.raw_status.failed?).to be_truthy
      end

      it "returns a normalized_status with a reason" do
        expect(stack.raw_status.normalized_status).to eq(["failed", "Failed to run template"])
      end
    end
  end

  describe "#raw_stdout" do
    let(:stack) { FactoryBot.create(:terraform_stack, :miq_task => miq_task) }
    let(:template) { FactoryBot.create(:terraform_template) }

    context "when miq_task.job present" do
      let(:terraform_runner_url) { "https://1.2.3.4:7000" }
      let(:hello_world_retrieve_response) do
        require 'json'
        JSON.parse(File.read(File.join(__dir__, "../../../../../lib/terraform/runner/data/responses/hello-world-retrieve-success.json")))
      end
      let(:miq_task) { FactoryBot.create(:miq_task, :job => job) }

      let(:job) do
        ManageIQ::Providers::EmbeddedTerraform::AutomationManager::Job.create_job(template, {}, {}, []).tap do |job|
          job.state = "finished"
          job.options = {
            :terraform_stack_id => hello_world_retrieve_response['stack_id']
          }
        end
      end

      let(:terraform_runner_stdout) { hello_world_retrieve_response['message'] }
      let(:terraform_runner_stdout_html) { TerminalToHtml.render(terraform_runner_stdout) }

      before do
        stub_const("ENV", ENV.to_h.merge("TERRAFORM_RUNNER_URL" => terraform_runner_url))

        stub_request(:post, "#{terraform_runner_url}/api/stack/retrieve")
          .with(:body => hash_including({:stack_id => hello_world_retrieve_response['stack_id']}))
          .to_return(
            :status => 200,
            :body   => hello_world_retrieve_response.to_json
          )
      end

      it "json" do
        expect(stack.raw_stdout("json")).to eq terraform_runner_stdout
      end

      it "txt" do
        expect(stack.raw_stdout("txt")).to eq terraform_runner_stdout
      end

      it "html" do
        expect(stack.raw_stdout("html")).to eq terraform_runner_stdout_html
      end

      it "nil" do
        expect(stack.raw_stdout).to eq terraform_runner_stdout
      end
    end

    shared_examples_for "terraform runner stdout not available from miq_task" do
      it "json" do
        expect(stack.raw_stdout("json")).to be_nil
      end

      it "txt" do
        expect(stack.raw_stdout("txt")).to be_nil
      end

      it "html" do
        expect(stack.raw_stdout("html")).to include <<~EOHTML
          <div class='term-container'>
          No output available
          </div>
        EOHTML
      end

      it "nil" do
        expect(stack.raw_stdout).to be_nil
      end
    end

    context "when miq_task is missing" do
      let(:miq_task) { nil }

      it_behaves_like "terraform runner stdout not available from miq_task"
    end

    context "when miq_task present, but missing miq_task.job" do
      let(:miq_task) { FactoryBot.create(:miq_task, :job => nil) }

      it_behaves_like "terraform runner stdout not available from miq_task"
    end

    context "when miq_task.job.options present but missing terraform_stack_id" do
      let(:job) do
        ManageIQ::Providers::EmbeddedTerraform::AutomationManager::Job.create_job(template, {}, {}, []).tap do |job|
          job.state = "waiting_to_start"
          job.options = {}
        end
      end

      let(:miq_task) { FactoryBot.create(:miq_task, :job => job) }

      it_behaves_like "terraform runner stdout not available from miq_task"
    end
  end

  describe "#raw_stdout_via_worker" do
    let(:stack) { FactoryBot.create(:terraform_stack) }

    context "when embedded_terraform role is enabled" do
      before do
        EmbeddedTerraformEvmSpecHelper.assign_embedded_terraform_role

        allow_any_instance_of(ManageIQ::Providers::EmbeddedTerraform::AutomationManager::ConfigurationScriptSource).to receive(:checkout_git_repository)
      end

      describe "#raw_stdout_via_worker with no errors" do
        before do
          EvmSpecHelper.local_miq_server
          allow(described_class).to receive(:find).and_return(stack)

          allow(MiqTask).to receive(:wait_for_taskid) do
            request = MiqQueue.find_by(:class_name => described_class.name)
            request.update(:state => MiqQueue::STATE_DEQUEUE)
            request.deliver_and_process
          end
        end

        it "gets stdout from the job" do
          expect(stack).to receive(:raw_stdout).and_return("A stdout from the job")
          taskid = stack.raw_stdout_via_worker("user")
          MiqTask.wait_for_taskid(taskid)
          expect(MiqTask.find(taskid)).to have_attributes(
            :task_results => "A stdout from the job",
            :status       => "Ok"
          )
        end

        it "returns the error message" do
          expect(stack).to receive(:raw_stdout).and_throw("Failed to get stdout from the job")
          taskid = stack.raw_stdout_via_worker("user")
          MiqTask.wait_for_taskid(taskid)
          expect(MiqTask.find(taskid).message).to include("Failed to get stdout from the job")
          expect(MiqTask.find(taskid).status).to eq("Error")
        end
      end
    end

    context "when embedded_terraform role is disabled" do
      describe "#raw_stdout_via_worker return error" do
        let(:role_enabled) { false }

        it "returns an error message" do
          taskid = stack.raw_stdout_via_worker("user")
          expect(MiqTask.find(taskid)).to have_attributes(
            :message => "Cannot get standard output of this terraform-template because the embedded terraform role is not enabled",
            :status  => "Error"
          )
        end
      end
    end
  end
end
