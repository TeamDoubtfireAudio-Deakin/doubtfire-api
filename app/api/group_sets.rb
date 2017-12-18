require 'grape'
require 'mime-check-helpers'

module Api
  #
  # Allow GroupSets to be managed via the API
  #
  class GroupSets < Grape::API
    helpers AuthenticationHelpers
    helpers AuthorisationHelpers
    helpers MimeCheckHelpers
    helpers LogHelper

    before do
      authenticated?
    end

    # ------------------------------------------------------------------------
    # Group Sets
    # ------------------------------------------------------------------------

    desc 'Add a new group set to the given unit'
    params do
      requires :unit_id, type: Integer, desc: 'The unit for the new group set'
      requires :group_set, type: Hash do
        requires :name,                             type: String,   desc: 'The name of this group set'
        optional :allow_students_to_create_groups,  type: Boolean,  desc: 'Are students allowed to create groups'
        optional :allow_students_to_manage_groups,  type: Boolean,  desc: 'Are students allowed to manage their group memberships'
        optional :keep_groups_in_same_class,        type: Boolean,  desc: 'Must groups be kept in the one class'
      end
    end
    post '/units/:unit_id/group_sets' do
      unit = Unit.find(params[:unit_id])
      unless authorise? current_user, unit, :update
        error!({ error: 'Not authorised to create a group set for this unit' }, 403)
      end

      logger.info "Create group set: #{current_user.username} in #{unit.code} from #{request.ip}"

      group_params = ActionController::Parameters.new(params)
                                                 .require(:group_set)
                                                 .permit(
                                                   :name,
                                                   :allow_students_to_create_groups,
                                                   :allow_students_to_manage_groups,
                                                   :keep_groups_in_same_class
                                                 )

      group_set = GroupSet.create!(group_params)
      group_set.unit = unit
      group_set.save!
      group_set
    end

    desc 'Edits the given group set'
    params do
      requires :id, type: Integer, desc: 'The group set id to edit'
      requires :group_set, type: Hash do
        optional :name,                             type: String,   desc: 'The name of this group set'
        optional :allow_students_to_create_groups,  type: Boolean,  desc: 'Are students allowed to create groups'
        optional :allow_students_to_manage_groups,  type: Boolean,  desc: 'Are students allowed to manage their group memberships'
        optional :keep_groups_in_same_class,        type: Boolean,  desc: 'Must groups be kept in the one class'
      end
    end
    put '/units/:unit_id/group_sets/:id' do
      group_set = GroupSet.find(params[:id])
      unit = Unit.find(params[:unit_id])

      logger.info "Edit group set: #{current_user.username} in #{unit.code} from #{request.ip}"

      if group_set.unit != unit
        error!({ error: 'Unable to locate group set for unit' }, 404)
      end

      unless authorise? current_user, unit, :update
        error!({ error: 'Not authorised to update group set for this unit' }, 403)
      end

      group_params = ActionController::Parameters.new(params)
                                                 .require(:group_set)
                                                 .permit(
                                                   :name,
                                                   :allow_students_to_create_groups,
                                                   :allow_students_to_manage_groups,
                                                   :keep_groups_in_same_class
                                                 )

      group_set.update!(group_params)
      group_set
    end

    desc 'Delete a group set'
    delete '/units/:unit_id/group_sets/:id' do
      group_set = GroupSet.find(params[:id])
      unit = Unit.find(params[:unit_id])

      logger.info "Delete group set: #{current_user.username} in #{unit.code} from #{request.ip}"

      if group_set.unit != unit
        error!({ error: 'Unable to locate group set for unit' }, 404)
      end

      unless authorise? current_user, unit, :update
        error!({ error: 'Not authorised to delete group set for this unit' }, 403)
      end

      error!(error: group_set.errors[:base].last) unless group_set.destroy
      nil
    end

    # ------------------------------------------------------------------------
    # Groups
    # ------------------------------------------------------------------------

    desc 'Get the groups in a group set'
    get '/units/:unit_id/group_sets/:id/groups' do
      unit = Unit.find(params[:unit_id])
      group_set = unit.group_sets.find(params[:id])

      unless authorise? current_user, group_set, :get_groups, ->(role, perm_hash, other) { group_set.specific_permission_hash(role, perm_hash, other) }
        error!({ error: 'Not authorised to get groups for this unit' }, 403)
      end

      group_set.groups
    end

    desc 'Download a CSV of groups in a group set'
    get '/units/:unit_id/group_sets/:group_set_id/groups/csv' do
      unit = Unit.find(params[:unit_id])
      group_set = unit.group_sets.find(params[:group_set_id])

      unless authorise? current_user, unit, :update
        error!({ error: 'Not authorised to download csv of groups for this unit' }, 403)
      end

      content_type 'application/octet-stream'
      header['Content-Disposition'] = "attachment; filename=#{unit.code}-groups.csv "
      env['api.format'] = :binary
      unit.export_groups_to_csv(group_set)
    end

    desc "Add a new group to the given unit's group_set"
    params do
      requires :unit_id,                            type: Integer,  desc: 'The unit for the new group'
      requires :group_set_id,                       type: Integer,  desc: 'The id of the group set'
      requires :group, type: Hash do
        optional :name,                             type: String,   desc: 'The name of this group'
        requires :tutorial_id,                      type: Integer,  desc: 'The id of the tutorial for the group'
      end
    end
    post '/units/:unit_id/group_sets/:group_set_id/groups' do
      unit = Unit.find(params[:unit_id])
      group_set = unit.group_sets.find(params[:group_set_id])
      tutorial = unit.tutorials.find(params[:group][:tutorial_id])

      unless authorise? current_user, group_set, :create_group, ->(role, perm_hash, other) { group_set.specific_permission_hash(role, perm_hash, other) }
        error!({ error: 'Not authorised to create a group set for this unit' }, 403)
      end

      group_params = ActionController::Parameters.new(params)
                                                 .require(:group)
                                                 .permit(
                                                   :name
                                                 )

      # Group with the same name
      unless group_set.groups.where(name: group_params[:name]).empty?
        error!({ error: "This group name is not unique to the #{group_set.name} group set." }, 403)
      end

      last = group_set.groups.last
      num = last.nil? ? 1 : last.number + 1
      if group_params[:name].nil? || group_params[:name].empty?
        group_params[:name] = "Group #{num}"
      end
      grp = Group.create(name: group_params[:name], group_set: group_set, tutorial: tutorial, number: num)
      grp.save!
      grp
    end

    desc 'Upload a CSV for groups in a group set'
    params do
      requires :unit_id,                            type: Integer,  desc: 'The unit for the new group'
      requires :group_set_id,                       type: Integer,  desc: 'The id of the group set'
      requires :file, type: Rack::Multipart::UploadedFile, desc: 'CSV upload file.'
    end
    post '/units/:unit_id/group_sets/:group_set_id/groups/csv' do
      # check mime is correct before uploading
      ensure_csv!(params[:file][:tempfile])

      unit = Unit.find(params[:unit_id])
      group_set = unit.group_sets.find(params[:group_set_id])

      unless authorise? current_user, unit, :update
        error!({ error: 'Not authorised to upload csv of groups for this unit' }, 403)
      end

      unit.import_groups_from_csv(group_set, params[:file][:tempfile])
    end

    desc 'Edits the given group'
    params do
      requires :unit_id,                            type: Integer,  desc: 'The unit for the new group'
      requires :group_set_id,                       type: Integer,  desc: 'The id of the group set'
      requires :group_id,                           type: Integer,  desc: 'The id of the group'
      requires :group, type: Hash do
        optional :name,                             type: String,   desc: 'The name of this group set'
        optional :tutorial_id,                      type: Integer,  desc: 'Tutorial of the group'
      end
    end
    put '/units/:unit_id/group_sets/:group_set_id/groups/:group_id' do
      unit = Unit.find(params[:unit_id])
      gs = unit.group_sets.find(params[:group_set_id])
      grp = gs.groups.find(params[:group_id])

      unless authorise? current_user, grp, :manage_group, ->(role, perm_hash, other) { grp.specific_permission_hash(role, perm_hash, other) }
        error!({ error: 'Not authorised to update this group' }, 403)
      end

      # Switching tutorials will violate any existing group members
      if !grp.group_memberships.empty? && params[:tutorial_id] != grp.tutorial.id && gs.keep_groups_in_same_class
        error!({ error: 'Cannot modify group tutorial as members already exist and they must be in the same tutorial. Clear all members first.' }, 403)
      end

      group_params = ActionController::Parameters.new(params)
                                                 .require(:group)
                                                 .permit(
                                                   :name,
                                                   :tutorial_id
                                                 )

      grp.update!(group_params)
      grp
    end

    desc 'Delete a group'
    params do
      requires :unit_id,      type: Integer,  desc: 'The unit for the new group'
      requires :group_set_id, type: Integer,  desc: 'The id of the group set'
      requires :group_id,     type: Integer,  desc: 'The id of the group'
    end
    delete '/units/:unit_id/group_sets/:group_set_id/groups/:group_id' do
      unit = Unit.find(params[:unit_id])
      gs = unit.group_sets.find(params[:group_set_id])
      grp = gs.groups.find(params[:group_id])

      unless authorise? current_user, grp, :manage_group, ->(role, perm_hash, other) { grp.specific_permission_hash(role, perm_hash, other) }
        error!({ error: 'Not authorised to delete group set for this unit' }, 403)
      end

      unless unit.tutors.include? current_user
        # check that they are the only member of the group, or the group is empty
        error!({ error: 'You cannot delete a group with members' }, 403) unless grp.projects.count <= 1
        error!({ error: 'You cannot delete this group' }, 403) unless grp.projects.count.zero? || grp.projects.first.student == current_user
      end

      error!(error: grp.errors[:base].last) unless grp.destroy
      nil
    end

    desc 'Get the members of a group'
    get '/units/:unit_id/group_sets/:group_set_id/groups/:group_id/members' do
      unit = Unit.find(params[:unit_id])
      group_set = unit.group_sets.find(params[:group_set_id])
      grp = group_set.groups.find(params[:group_id])

      unless authorise? current_user, grp, :get_members, ->(role, perm_hash, other) { grp.specific_permission_hash(role, perm_hash, other) }
        error!({ error: 'Not authorised to get groups for this unit' }, 403)
      end

      Thread.current[:user] = current_user
      ActiveModel::ArraySerializer.new(grp.projects, each_serializer: GroupMemberProjectSerializer)
    end

    desc 'Add a group member'
    params do
      requires :unit_id,                            type: Integer,  desc: 'The unit for the new group'
      requires :group_set_id,                       type: Integer,  desc: 'The id of the group set'
      requires :group_id,                           type: Integer,  desc: 'The id of the group'
      requires :project_id,                         type: Integer,  desc: 'The project id of the member'
    end
    post '/units/:unit_id/group_sets/:group_set_id/groups/:group_id/members' do
      unit = Unit.find(params[:unit_id])
      gs = unit.group_sets.find(params[:group_set_id])
      grp = gs.groups.find(params[:group_id])

      prj = unit.projects.find(params[:project_id])

      unless authorise? current_user, gs, :join_group, ->(role, perm_hash, other) { gs.specific_permission_hash(role, perm_hash, other) }
        error!({ error: 'Not authorised to manage this group' }, 403)
      end

      unless authorise? current_user, prj, :get
        error!({ error: 'Not authorised to manage this student' }, 403)
      end

      if gs.keep_groups_in_same_class && prj.tutorial != grp.tutorial
        error!({ error: "Students from the tutorial '#{grp.tutorial.abbreviation}' can only be added to this group." }, 403)
      end

      if grp.group_memberships.find_by(project: prj, active: true)
        error!({ error: "#{prj.student.name} is already a member of this group" }, 403)
      end

      gm = grp.add_member(prj)
      Thread.current[:user] = current_user
      GroupMemberProjectSerializer.new(prj)
    end

    desc 'Remove a group member'
    params do
      requires :unit_id,                            type: Integer,  desc: 'The unit for the new group'
      requires :group_set_id,                       type: Integer,  desc: 'The id of the group set'
      requires :group_id,                           type: Integer,  desc: 'The id of the group'
      requires :id,                                 type: Integer,  desc: 'The project id of the member'
    end
    delete '/units/:unit_id/group_sets/:group_set_id/groups/:group_id/members/:id' do
      unit = Unit.find(params[:unit_id])
      gs = unit.group_sets.find(params[:group_set_id])
      grp = gs.groups.find(params[:group_id])
      prj = grp.projects.find(params[:id])

      unless authorise? current_user, grp, :manage_group, ->(role, perm_hash, other) { grp.specific_permission_hash(role, perm_hash, other) }
        error!({ error: 'Not authorised to manage this group' }, 403)
      end

      unless authorise? current_user, prj, :get
        error!({ error: 'Not authorised to manage this student' }, 403)
      end

      if grp.group_memberships.find_by(project: prj).nil?
        error!({ error: "#{prj.student.name} is not a member of this group" }, 403)
      end

      grp.remove_member(prj)
      nil
    end
  end
end
