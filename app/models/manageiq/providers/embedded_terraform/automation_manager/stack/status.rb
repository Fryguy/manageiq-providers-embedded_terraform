class ManageIQ::Providers::EmbeddedTerraform::AutomationManager::Stack::Status < OrchestrationStack::Status
  attr_accessor :task_status

  def initialize(miq_task, reason)
    super(miq_task.state, reason)
    self.task_status = miq_task.status
  end

  def completed?
    status == MiqTask::STATE_FINISHED
  end

  def succeeded?
    completed? && task_status == MiqTask::STATUS_OK
  end

  def failed?
    completed? && task_status != MiqTask::STATUS_OK
  end
end
