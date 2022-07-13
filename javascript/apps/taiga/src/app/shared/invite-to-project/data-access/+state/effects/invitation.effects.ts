/**
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 *
 * Copyright (c) 2021-present Kaleidos Ventures SL
 */

import { Injectable } from '@angular/core';
import { Actions, concatLatestFrom, createEffect, ofType } from '@ngrx/effects';
import { catchError, debounceTime, map, switchMap, tap } from 'rxjs/operators';
import * as InvitationActions from '../actions/invitation.action';
import * as NewProjectActions from '~/app/modules/feature-new-project/+state/actions/new-project.actions';
import { InvitationApiService } from '@taiga/api';
import { optimisticUpdate, pessimisticUpdate } from '@nrwl/angular';
import { AppService } from '~/app/services/app.service';
import { HttpErrorResponse } from '@angular/common/http';
import {
  Contact,
  ErrorManagementToastOptions,
  InvitationResponse,
} from '@taiga/data';
import { TuiNotification } from '@taiga-ui/core';
import { ButtonLoadingService } from '~/app/shared/directives/button-loading/button-loading.service';
import { InvitationService } from '~/app/services/invitation.service';
import { ProjectApiService } from '@taiga/api';
import { selectUser } from '~/app/modules/auth/data-access/+state/selectors/auth.selectors';
import { Store } from '@ngrx/store';
import { filterNil } from '~/app/shared/utils/operators';
import { throwError } from 'rxjs';

@Injectable()
export class InvitationEffects {
  public sendInvitations$ = createEffect(() => {
    return this.actions$.pipe(
      ofType(NewProjectActions.inviteUsersToProject),
      pessimisticUpdate({
        run: (action) => {
          this.buttonLoadingService.start();
          return this.invitationApiService
            .inviteUsers(action.slug, action.invitation)
            .pipe(
              switchMap(this.buttonLoadingService.waitLoading()),
              map((response: InvitationResponse) => {
                return InvitationActions.inviteUsersSuccess({
                  newInvitations: response.invitations,
                  alreadyMembers: response.alreadyMembers,
                });
              })
            );
        },
        onError: (action, httpResponse: HttpErrorResponse) => {
          this.buttonLoadingService.error();
          const options: ErrorManagementToastOptions = {
            type: 'toast',
            options: {
              label: 'invitation_error',
              message: 'failed_send_invite',
              paramsMessage: { invitations: action.invitation.length },
              status: TuiNotification.Error,
              scope: 'invitation_modal',
            },
          };
          this.appService.errorManagement(httpResponse, {
            400: options,
            500: options,
          });
          return InvitationActions.inviteUsersError();
        },
      })
    );
  });

  public sendInvitationsSuccess$ = createEffect(
    () => {
      return this.actions$.pipe(
        ofType(InvitationActions.inviteUsersSuccess),
        tap((action) => {
          let labelText;
          let messageText;
          let paramsMessage;
          let paramsLabel;
          if (action.newInvitations.length && action.alreadyMembers) {
            labelText = 'invitation_success';
            messageText = 'only_members_success';
            paramsMessage = { members: action.alreadyMembers };
            paramsLabel = { invitations: action.newInvitations.length };
          } else if (action.newInvitations.length && !action.alreadyMembers) {
            labelText = 'invitation_ok';
            messageText = 'invitation_success';
            paramsMessage = { invitations: action.newInvitations.length };
          } else if (!action.newInvitations.length && action.alreadyMembers) {
            if (action.alreadyMembers === 1) {
              messageText = 'only_member_success';
            } else {
              messageText = 'only_members_success';
              paramsMessage = { members: action.alreadyMembers };
            }
          } else {
            messageText = '';
          }

          this.appService.toastNotification({
            label: labelText,
            message: messageText,
            paramsMessage,
            paramsLabel,
            status: action.newInvitations.length
              ? TuiNotification.Success
              : TuiNotification.Info,
            scope: 'invitation_modal',
            autoClose: true,
          });
        })
      );
    },
    { dispatch: false }
  );

  public acceptInvitationSlug$ = createEffect(() => {
    return this.actions$.pipe(
      ofType(InvitationActions.acceptInvitationSlug),
      optimisticUpdate({
        run: (action) => {
          return this.projectApiService.acceptInvitationSlug(action.slug).pipe(
            concatLatestFrom(() =>
              this.store.select(selectUser).pipe(filterNil())
            ),
            map(([, user]) => {
              return InvitationActions.acceptInvitationSlugSuccess({
                projectSlug: action.slug,
                username: user.username,
              });
            })
          );
        },
        undoAction: (action) => {
          this.appService.toastNotification({
            label: 'errors.generic_toast_label',
            message: 'errors.generic_toast_message',
            status: TuiNotification.Error,
          });

          return InvitationActions.acceptInvitationSlugError({
            projectSlug: action.slug,
          });
        },
      })
    );
  });

  public searchUser$ = createEffect(() => {
    return this.actions$.pipe(
      ofType(InvitationActions.searchUser),
      debounceTime(200),
      concatLatestFrom(() => this.store.select(selectUser).pipe(filterNil())),
      switchMap(([action, userState]) => {
        const peopleAddedMatch = this.invitationService.matchUsersFromList(
          action.peopleAdded,
          action.searchUser.text
        );
        const peopleAddedUsernameList = action.peopleAdded.map(
          (i) => i.username
        );
        return this.invitationApiService
          .searchUser({
            text: this.invitationService.normalizeText(action.searchUser.text),
            project: action.searchUser.project,
            offset: 0,
            // to show 6 results at least and being possible to get the current user in the list we always will ask for 7 + the matched users that are on the list
            limit: peopleAddedMatch.length + 7,
          })
          .pipe(
            map((suggestedUsers: Contact[]) => {
              let suggestedList = suggestedUsers.filter(
                (suggestedUser) =>
                  suggestedUser.username !== userState.username &&
                  !peopleAddedUsernameList.includes(suggestedUser.username) &&
                  !suggestedUser.userIsMember
              );
              const alreadyMembers = suggestedUsers.filter(
                (suggestedUser) =>
                  suggestedUser.username !== userState.username &&
                  suggestedUser.userIsMember
              );
              suggestedList = [
                ...alreadyMembers,
                ...peopleAddedMatch,
                ...suggestedList,
              ].slice(0, 6);

              return InvitationActions.searchUserSuccess({
                suggestedUsers: suggestedList,
              });
            })
          );
      }),
      catchError((httpResponse: HttpErrorResponse) => {
        this.appService.errorManagement(httpResponse);
        return throwError(httpResponse);
      })
    );
  });

  constructor(
    private store: Store,
    private actions$: Actions,
    private invitationApiService: InvitationApiService,
    private invitationService: InvitationService,
    private appService: AppService,
    private buttonLoadingService: ButtonLoadingService,
    private projectApiService: ProjectApiService
  ) {}
}
