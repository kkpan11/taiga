/**
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 *
 * Copyright (c) 2021-present Kaleidos Ventures SL
 */

import {
  ChangeDetectionStrategy,
  Component,
  ElementRef,
  EventEmitter,
  HostListener,
  Input,
  OnChanges,
  OnInit,
  Output,
  SimpleChanges,
  ViewChild,
} from '@angular/core';
import { FormArray, FormBuilder, FormGroup } from '@angular/forms';
import { Store } from '@ngrx/store';
import {
  Membership,
  Invitation,
  InvitationRequest,
  Project,
  Role,
  User,
} from '@taiga/data';
import { initRolesPermissions } from '~/app/modules/project/settings/feature-roles-permissions/+state/actions/roles-permissions.actions';
import {
  fetchMyContacts,
  inviteUsersSuccess,
} from '~/app/shared/invite-to-project/data-access/+state/actions/invitation.action';
import {
  selectContacts,
  selectMemberRolesOrdered,
  selectUsersToInvite,
} from '~/app/shared/invite-to-project/data-access/+state/selectors/invitation.selectors';
import { selectUser } from '~/app/modules/auth/data-access/+state/selectors/auth.selectors';
import { BehaviorSubject, Observable } from 'rxjs';
import {
  map,
  share,
  skip,
  startWith,
  switchMap,
  throttleTime,
} from 'rxjs/operators';
import { TRANSLOCO_SCOPE } from '@ngneat/transloco';
import { inviteUsersNewProject } from '~/app/modules/feature-new-project/+state/actions/new-project.actions';
import { Actions, concatLatestFrom, ofType } from '@ngrx/effects';
import { UntilDestroy, untilDestroyed } from '@ngneat/until-destroy';
import { TuiTextAreaComponent } from '@taiga-ui/kit';
import { TuiScrollbarComponent } from '@taiga-ui/core';
import { InvitationService } from '~/app/services/invitation.service';

@UntilDestroy()
@Component({
  selector: 'tg-invite-to-project',
  templateUrl: './invite-to-project.component.html',
  styleUrls: [
    './styles/invite-to-project.shared.css',
    './invite-to-project.component.css',
  ],
  changeDetection: ChangeDetectionStrategy.OnPush,
  providers: [
    {
      provide: TRANSLOCO_SCOPE,
      useValue: {
        scope: 'invitation_modal',
        alias: 'invitation_modal',
      },
    },
  ],
})
export class InviteToProjectComponent implements OnInit, OnChanges {
  @ViewChild(TuiScrollbarComponent, { read: ElementRef })
  private readonly scrollBar?: ElementRef<HTMLElement>;

  @Input()
  public project!: Project;

  @Input()
  public pending?: Invitation[];

  @Input()
  public reset?: boolean;

  @Input()
  public members?: (Membership | Invitation)[];

  @Output()
  public closeModal = new EventEmitter();

  @ViewChild('emailInput', { static: false })
  public emailInput!: TuiTextAreaComponent;

  @HostListener('window:beforeunload')
  public unloadHandler() {
    return !this.formHasContent();
  }

  public regexpEmail = /\w+([.\-_+]?\w+)*@\w+([.-]?\w+)*(\.\w{2,4})+/g;
  public inviteEmails = '';
  public inviteEmails$ = new BehaviorSubject('');
  public inviteEmailsErrors: {
    required: boolean;
    regex: boolean;
    listEmpty: boolean;
    peopleNotAdded: boolean;
    bulkError: boolean;
    moreThanFifty: boolean;
  } = {
    required: false,
    regex: false,
    listEmpty: false,
    peopleNotAdded: false,
    bulkError: false,
    moreThanFifty: false,
  };
  public inviteProjectForm: FormGroup = this.fb.group({
    users: new FormArray([]),
  });
  public orderedRoles!: Role[] | null;

  public validEmails$ = new BehaviorSubject([] as string[]);
  public memberRoles$ = this.store.select(selectMemberRolesOrdered);
  public contacts$ = this.store.select(selectContacts);
  public usersToInvite$!: Observable<Partial<User>[]>;
  public validInviteEmails$!: Observable<RegExpMatchArray>;
  public emailsWithoutDuplications$!: Observable<string[]>;

  constructor(
    private fb: FormBuilder,
    private store: Store,
    private actions$: Actions,
    private invitationService: InvitationService
  ) {
    this.actions$
      .pipe(ofType(inviteUsersSuccess), untilDestroyed(this))
      .subscribe(() => {
        this.close();
      });

    this.validInviteEmails$ = this.inviteEmails$.pipe(
      throttleTime(200, undefined, { leading: true, trailing: true }),
      map((emails) => this.validateEmails(emails)),
      share(),
      startWith([])
    );

    this.emailsWithoutDuplications$ = this.validInviteEmails$.pipe(
      map((emails) => {
        return emails?.filter((email, i) => emails.indexOf(email) === i);
      }),
      share(),
      startWith([])
    );
  }

  public get users() {
    return (this.inviteProjectForm.controls['users'] as FormArray)
      .controls as FormGroup[];
  }

  public get validEmails() {
    return this.validEmails$.value;
  }

  public get emailsHaveErrors() {
    return (
      this.inviteEmailsErrors.required ||
      this.inviteEmailsErrors.regex ||
      this.inviteEmailsErrors.peopleNotAdded ||
      this.inviteEmailsErrors.bulkError
    );
  }

  public ngOnInit() {
    this.usersToInvite$ = this.validEmails$.pipe(
      switchMap((validEmails) => {
        return this.store
          .select(selectUsersToInvite(validEmails))
          .pipe(skip(1));
      })
    );

    this.store.dispatch(initRolesPermissions({ project: this.project }));

    // when we add users to invite its necessary to add the result to the form
    this.usersToInvite$
      .pipe(concatLatestFrom(() => this.store.select(selectUser)))
      .subscribe(([userToInvite, currentUser]) => {
        userToInvite.forEach((user) => {
          const userAlreadyExist = this.users?.find((it: FormGroup) => {
            return (it.value as Partial<User>).email === user.email;
          });
          const isCurrentUser = currentUser?.email === user.email;
          const isAlreadyProjectMember =
            !!user.username &&
            this.members
              ?.filter((it) => !(it as Invitation).email)
              ?.find((member) => member.user?.username === user.username);
          !userAlreadyExist &&
            !isCurrentUser &&
            !isAlreadyProjectMember &&
            this.users.splice(
              this.positionInArray(user),
              0,
              this.fb.group(user)
            );
        });
        this.inviteEmails = '';
        this.emailsChange('');
        this.emailInput?.nativeFocusableElement?.focus();
      });

    this.memberRoles$.subscribe((memberRoles) => {
      this.orderedRoles = memberRoles;
    });
  }

  public ngOnChanges(changes: SimpleChanges) {
    changes.reset && this.cleanForm();
  }

  public positionInArray(user: Partial<User>) {
    const tempInvitations = this.users.map((it) => {
      const data = it.value as {
        fullName: string;
        username?: string;
        roles: string;
        email: string;
      };
      return {
        user:
          data.username && data.fullName
            ? { username: data.username, fullName: data.fullName }
            : undefined,
        email: data.email || '',
        role: {
          isAdmin: data.roles === 'Administrator',
          name: data.roles,
        },
      };
    });
    const tempInvitation = {
      user:
        user.username && user.fullName
          ? { username: user.username, fullName: user.fullName }
          : undefined,
      email: user.email || '',
      role: {
        isAdmin: (user.roles && user.roles[0]) === 'Administrator',
        name: user.roles && user.roles[0],
      },
    };
    return this.invitationService.positionInvitationInArray(
      tempInvitations,
      tempInvitation
    );
  }

  public validateEmails(emails: string) {
    return emails.match(this.regexpEmail) || [];
  }

  public formHasContent() {
    return !!this.inviteEmails || !!this.users.length;
  }

  public trackByIndex(index: number) {
    return index;
  }

  public isPending(email: string) {
    return !!this.pending?.find((it) => it.email === email);
  }

  public emailsChange(emails: string) {
    !emails && this.resetErrors();

    this.inviteEmails$.next(emails);
  }

  public resetErrors() {
    this.inviteEmailsErrors = {
      required: false,
      regex: false,
      listEmpty: false,
      peopleNotAdded: false,
      bulkError: false,
      moreThanFifty: false,
    };
  }

  public filterValidEmails(value: string) {
    return value.match(this.regexpEmail) || [];
  }

  public addUser() {
    const emailRgx = this.regexpEmail.test(this.inviteEmails);
    const bulkErrors = this.inviteEmails
      .replace(this.regexpEmail, '')
      .replace(/[;,\s\n]/g, '');

    this.resetErrors();
    if (this.inviteEmails === '') {
      this.inviteEmailsErrors.required = true;
    } else if (!emailRgx) {
      this.inviteEmailsErrors.regex = true;
    } else if (bulkErrors) {
      this.inviteEmailsErrors.bulkError = true;
    } else {
      this.validEmails$.next(this.filterValidEmails(this.inviteEmails));
      this.store.dispatch(fetchMyContacts({ emails: this.validEmails }));
    }
  }

  public deleteUser(i: number) {
    (this.inviteProjectForm.controls['users'] as FormArray).removeAt(i);

    // force recalculate scroll height in Firefox
    requestAnimationFrame(() => {
      if (this.scrollBar) {
        this.scrollBar.nativeElement.scrollTop = 0;
        this.scrollBar.nativeElement.scrollTop =
          this.scrollBar.nativeElement.scrollHeight;
      }
    });
  }

  public getRoleSlug(roleName: string) {
    return this.orderedRoles?.find((role) => role.name === roleName);
  }

  public generatePayload(): InvitationRequest[] {
    return this.users.map((user) => {
      return {
        email: user.get('email')?.value as string,
        roleSlug:
          this.getRoleSlug(user.get('roles')?.value as string)?.slug || '',
      };
    });
  }

  public sendForm() {
    this.resetErrors();
    if (this.users.length > 50) {
      this.inviteEmailsErrors.moreThanFifty = true;
    } else if (this.users.length && this.inviteEmails === '') {
      this.store.dispatch(
        inviteUsersNewProject({
          slug: this.project.slug,
          invitation: this.generatePayload(),
        })
      );
    } else if (this.inviteEmails === '') {
      this.inviteEmailsErrors.listEmpty = true;
      this.emailInput?.nativeFocusableElement?.focus();
    }
    this.inviteEmailsErrors.peopleNotAdded = !!this.inviteEmails;
  }

  public cleanForm() {
    this.resetErrors();
    this.inviteEmails = '';
    this.emailsChange('');
    this.inviteProjectForm = this.fb.group({
      users: new FormArray([]),
    });
  }

  public close() {
    this.cleanForm();
    this.closeModal.next();
  }
}
