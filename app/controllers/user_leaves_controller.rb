class UserLeavesController < ApplicationController
  unloadable
  
  include UserLeaveReportsHelper
  include UserLeavesHelper

  def new
    if !(!mark_leave_users.include?(User.current) && !mark_own_leave_users.include?(User.current))
      @user_leave = UserLeave.new
    else
      return deny_access
    end        
  end
  
  def create  
    errors = []
    selected_users = []
    if params['create_user_leave']['selected_users']
      selected_users = params['create_user_leave']['selected_users']
    else
      selected_users = User.active.joins(:groups).
        where("#{User.table_name_prefix}groups_users#{User.table_name_suffix}.id" => params['create_user_leave']['selected_groups']).map(&:id)
    end
    if params['create_user_leave']['selected_date_from'].blank? || 
        params['create_user_leave']['selected_date_to'].blank?
      errors << "Date Field(s) cannot be empty!"
    else
      begin
        selected_date_from = params['create_user_leave']['selected_date_from'].to_date#.map{|k,v| v}.join("-").to_date
        selected_date_to   = params['create_user_leave']['selected_date_to'].to_date#.map{|k,v| v}.join("-").to_date    
      rescue
        errors << "Invalid Date Format!"
      end
    end
    selected_users = check_selected_users(selected_users)
    notices = []
    if !selected_users.empty? && errors.empty?
      selected_users = selected_users.uniq
      selected_users.each do |user|
        leave_date = selected_date_from
        while leave_date <= selected_date_to
          user_leave = UserLeave.new(user_id: user.to_i, leave_type: params['create_user_leave']['selected_leave'],
            leave_date: leave_date, comments: params['create_user_leave']['comments'], 
            fractional_leave: params['create_user_leave']['fractional_leave'])
          leave_date += 1
          unless user_leave.save
            errors << l(:error_leave_add, user_name: user_leave.user.name, leave_type: user_leave.leave_type, 
                        leave_date: user_leave.leave_date, reason: user_leave.errors.full_messages.join('<br/>'))
          else
            total_yearly_leaves = UserLeave.where(user_id: user, leave_type: user_leave.leave_type).where("leave_date >= ?", Date.today.beginning_of_year).sum(:fractional_leave)
            notices << l(:notice_leave_add, user_name: user_leave.user.name, 
              leave_type: user_leave.leave_type, 
              leave_date: user_leave.leave_date, total_yearly_leaves: total_yearly_leaves)
          end 
        end       
      end
      errors = errors.flatten.uniq
      notices = notices.flatten.uniq
      unless errors.blank?
        flash.now[:notice] = "#{notices.join('<br/>')}"
        flash.now[:error] = "#{errors.join('<br/>')}"
        render 'new'
      else
        redirect_to user_leave_reports_path, notice: "#{notices.join('<br/>')}"
      end
    else
      flash.now[:error] = l(:error_no_user_group_selected)
      render 'new'
    end
  end
  
  def edit
    @user_leave = UserLeave.find(params[:id])
  end
  
  def update    
    @user_leave = UserLeave.find(params[:id])
    if @user_leave.update_attributes(params.require(:user_leave).permit!)
      redirect_to edit_user_leafe_path(@user_leave), notice: l(:notice_leaves_updated)
    else
      redirect_to edit_user_leafe_path(@user_leave), error: l(:error_leaves_not_updated)
    end    
  end
    
  def destroy
    @user_leave = UserLeave.find(params[:id])
    @user_leave.destroy
    respond_to do |format|
      format.js {}
    end 
  end
end

