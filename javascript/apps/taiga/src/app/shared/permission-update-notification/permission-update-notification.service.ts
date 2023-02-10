/**
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 *
 * Copyright (c) 2021-present Kaleidos Ventures SL
 */

import { Injectable } from '@angular/core';
import { TuiNotification } from '@taiga-ui/core';
import { Project } from '@taiga/data';
import { AppService } from '~/app/services/app.service';
import { PermissionsService } from '~/app/services/permissions.service';

@Injectable({
  providedIn: 'root',
})
export class PermissionUpdateNotificationService {
  constructor(
    private permissionService: PermissionsService,
    private appService: AppService
  ) {}

  public notifyLosePermissions(
    previousProject: Project,
    currentProject: Project
  ) {
    if (
      previousProject?.userPermissions.length >
      currentProject?.userPermissions.length
    ) {
      const hasStoryPermissions = this.permissionService.hasPermissions(
        'story',
        ['create', 'delete', 'modify'],
        'OR'
      );
      if (hasStoryPermissions) {
        this.notify('edit_story_lost_some_permission');
      } else {
        this.notify('edit_story_lost_permission');
      }
    }
  }

  public notify(translation: string) {
    this.appService.toastNotification({
      message: translation,
      status: TuiNotification.Warning,
      scope: 'kanban',
      autoClose: true,
    });
  }
}