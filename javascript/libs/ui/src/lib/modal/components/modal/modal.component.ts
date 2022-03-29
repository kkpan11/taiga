/**
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 *
 * Copyright (c) 2021-present Kaleidos Ventures SL
 */

import {
  Component,
  ChangeDetectionStrategy,
  Input,
  ViewChild,
  AfterViewInit,
  Output,
  EventEmitter,
} from '@angular/core';
import { BehaviorSubject, merge, Subscription } from 'rxjs';
import { ShortcutsService } from '@taiga/core';
import { PolymorpheusContent } from '@tinkoff/ng-polymorpheus';
import { TuiDialogService } from '@taiga-ui/core';
import { UntilDestroy, untilDestroyed } from '@ngneat/until-destroy';
import { ModalService } from '@taiga/ui/modal/services/modal.service';

/*
Usage example:
<tg-ui-modal
  [open]="open"
  (requestClose)="open = !open">
  <h1>Hi!</h1>
  <my-modal-component></my-modal-component>
</tg-ui-modal>
*/
@UntilDestroy()
@Component({
  selector: 'tg-ui-modal',
  templateUrl: './modal.component.html',
  styleUrls: ['./modal.component.css'],
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class ModalComponent implements AfterViewInit {
  public open$ = new BehaviorSubject<boolean>(false);

  @Output()
  public requestClose = new EventEmitter<void>();

  @Input()
  public elementFocusWhenClosed?: HTMLElement;

  @Input()
  public set open(value: boolean) {
    this.open$.next(value);
  }

  public get open() {
    return this.open$.value;
  }

  @ViewChild('domPortalContent')
  public domPortalContent!: PolymorpheusContent<HTMLElement>;

  public modalSubscription$?: Subscription;

  constructor(
    public modalService: ModalService,
    public dialogService: TuiDialogService,
    public shortcutsService: ShortcutsService
  ) {}

  public ngAfterViewInit() {
    this.open$.pipe(untilDestroyed(this)).subscribe((open) => {
      if (open) {
        this.processOpen();
      } else {
        this.processClose();
      }
    });
  }

  public close() {
    this.requestClose.next();
  }

  private processOpen() {
    this.shortcutsService.setScope('modal');

    this.modalSubscription$ = merge(
      this.modalService.open(this.domPortalContent, {}),
      this.shortcutsService.task('modal.close')
    )
      .pipe(untilDestroyed(this))
      .subscribe(() => {
        this.close();
      });
  }

  private processClose() {
    this.modalSubscription$?.unsubscribe();
    this.shortcutsService.resetScope();
  }
}