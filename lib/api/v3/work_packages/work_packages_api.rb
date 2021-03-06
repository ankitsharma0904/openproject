#-- copyright
# OpenProject is a project management system.
# Copyright (C) 2012-2015 the OpenProject Foundation (OPF)
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License version 3.
#
# OpenProject is a fork of ChiliProject, which is a fork of Redmine. The copyright follows:
# Copyright (C) 2006-2013 Jean-Philippe Lang
# Copyright (C) 2010-2013 the ChiliProject Team
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
#
# See doc/COPYRIGHT.rdoc for more details.
#++

require 'api/v3/work_packages/work_package_representer'

module API
  module V3
    module WorkPackages
      class WorkPackagesAPI < ::API::OpenProjectAPI
        resources :work_packages do
          helpers ::API::V3::WorkPackages::WorkPackageListHelpers

          get do
            authorize(:view_work_packages, global: true)
            work_packages_by_params
          end

          params do
            requires :id, desc: 'Work package id'
          end
          route_param :id do
            helpers WorkPackagesSharedHelpers
            helpers do
              attr_reader :work_package

              def work_package_representer
                ::API::V3::WorkPackages::WorkPackageRepresenter.create(
                  @work_package,
                  current_user: current_user,
                  embed_links: true
                )
              end
            end

            before do
              @work_package = WorkPackage.find(params[:id])

              authorize(:view_work_packages, context: @work_package.project) do
                raise API::Errors::NotFound.new
              end
            end

            get do
              work_package_representer
            end

            patch do
              write_work_package_attributes(@work_package, reset_lock_version: true)

              send_notifications = !(params.has_key?(:notify) && params[:notify] == 'false')
              update_service = UpdateWorkPackageService.new(
                user: current_user,
                work_package: @work_package,
                send_notifications: send_notifications)

              contract = UpdateContract.new(@work_package, current_user)
              if contract.validate && update_service.save
                @work_package.reload

                work_package_representer
              else
                fail ::API::Errors::ErrorBase.create_and_merge_errors(contract.errors)
              end
            end

            mount ::API::V3::WorkPackages::WatchersAPI
            mount ::API::V3::Relations::RelationsAPI
            mount ::API::V3::Activities::ActivitiesByWorkPackageAPI
            mount ::API::V3::Attachments::AttachmentsByWorkPackageAPI
            mount ::API::V3::Repositories::RevisionsByWorkPackageAPI
            mount ::API::V3::WorkPackages::UpdateFormAPI
          end

          mount ::API::V3::WorkPackages::Schema::WorkPackageSchemasAPI
        end
      end
    end
  end
end
