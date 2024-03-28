class ApplicationHelper::Toolbar::EmbeddedTerraformCredentialCenter < ApplicationHelper::Toolbar::Basic
  button_group('embedded_terraform_credential', [
                 select(
                   :embedded_terraform_credential_configuration,
                   nil,
                   t = N_('Configuration'),
                   t,
                   :items => [
                     button(
                       :embedded_automation_manager_credentials_edit,
                       'pficon pficon-edit fa-lg',
                       t = N_('Edit this Credential'),
                       t,
                       :klass => ApplicationHelper::Button::EmbeddedTerraform,
                       :url   => "/edit"
                     ),
                     button(
                       :embedded_automation_manager_credentials_delete,
                       'pficon pficon-delete fa-lg',
                       t = N_('Remove this Credential from Inventory'),
                       t,
                       :klass => ApplicationHelper::Button::EmbeddedTerraform,
                       :data  => {'function'      => 'sendDataWithRx',
                                  'function-data' => {:controller     => 'provider_dialogs',
                                                      :modal_title    => N_('Delete Credential'),
                                                      :modal_text     => N_('Are you sure you want to delete the following credential?'),
                                                      :api_url        => 'authentications',
                                                      :async_delete   => true,
                                                      :redirect_url   => '/embedded_terraform_credential/show_list',
                                                      :component_name => 'RemoveGenericItemModal'}}
                     ),
                   ]
                 ),
               ])
  button_group('embedded_terraform_credentials_policy', [
                 select(
                   :embedded_terraform_credentials_policy_choice,
                   nil,
                   t = N_('Policy'),
                   t,
                   :items => [
                     button(
                       :ansible_credential_tag,
                       'pficon pficon-edit fa-lg',
                       N_('Edit Tags for this Embedded Terraform Credential'),
                       N_('Edit Tags')
                     ),
                   ]
                 )
               ])
end
