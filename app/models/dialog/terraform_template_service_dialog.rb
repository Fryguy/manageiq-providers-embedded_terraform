class Dialog
  class TerraformTemplateServiceDialog
    def self.create_dialog(label, terraform_template, extra_vars)
      new.create_dialog(label, terraform_template, extra_vars)
    end

    # This dialog is to be used by a terraform template service item
    def create_dialog(label, terraform_template, extra_vars)
      Dialog.new(:label => label, :buttons => "submit,cancel").tap do |dialog|
        tab = dialog.dialog_tabs.build(:display => "edit", :label => "Basic Information", :position => 0)
        position = 0
        if terraform_template.present?
          add_template_variables_group(tab, position, terraform_template)
          position += 1
        end
        if extra_vars.present?
          add_variables_group(tab, position, extra_vars)
        end
        dialog.save!
      end
    end

    private

    def add_template_variables_group(tab, position, terraform_template)
      require "json"
      template_info = JSON.parse(terraform_template.payload)
      input_vars = template_info["input_vars"]

      return if input_vars.nil?

      tab.dialog_groups.build(
        :display  => "edit",
        :label    => "Terraform Template Variables",
        :position => position
      ).tap do |dialog_group|
        input_vars.each_with_index do |(var_info), index|
          key, value, required, readonly, hidden, label, description = var_info.values_at(
            "name", "default", "required", "immutable", "hidden", "label", "description"
          )
          # TODO: use these when adding variable field
          # type, secured = var_info.values_at("type", "secured")

          next if hidden

          add_variable_field(
            key, value, dialog_group, index, label, description, required, readonly
          )
        end
      end
    end

    def add_variables_group(tab, position, extra_vars)
      tab.dialog_groups.build(
        :display  => "edit",
        :label    => "Extra Variables",
        :position => position
      ).tap do |dialog_group|
        extra_vars.transform_values { |val| val[:default] }.each_with_index do |(key, value), index|
          add_variable_field(key, value, dialog_group, index, key, key, false, false)
        end
      end
    end

    def add_variable_field(key, value, group, position, label, description, required, read_only)
      value = value.to_json if [Hash, Array].include?(value.class)
      description = key if description.blank?

      group.dialog_fields.build(
        :type           => "DialogFieldTextBox",
        :name           => "#{key}",
        :data_type      => "string",
        :display        => "edit",
        :required       => required,
        :default_value  => value,
        :label          => label,
        :description    => description,
        :reconfigurable => true,
        :position       => position,
        :dialog_group   => group,
        :read_only      => read_only
      )
    end
  end
end
