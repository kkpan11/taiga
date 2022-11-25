# -*- coding: utf-8 -*-
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2021-present Kaleidos Ventures SL

from typing import Literal, TypedDict
from uuid import UUID

from asgiref.sync import sync_to_async
from taiga.base.db.models import Q, QuerySet
from taiga.projects.invitations.choices import ProjectInvitationStatus
from taiga.projects.invitations.models import ProjectInvitation
from taiga.projects.projects.models import Project
from taiga.users.models import User

##########################################################
# filters and querysets
##########################################################


DEFAULT_QUERYSET = ProjectInvitation.objects.all()


class ProjectInvitationListFilters(TypedDict, total=False):
    project_id: UUID
    user: User
    status: ProjectInvitationStatus
    statuses: list[ProjectInvitationStatus]


def _apply_filters_to_queryset_list(
    qs: QuerySet[ProjectInvitation],
    filters: ProjectInvitationListFilters = {},
) -> QuerySet[ProjectInvitation]:
    filter_data = dict(filters.copy())

    if "project_id" in filter_data:
        filter_data["project__id"] = filter_data.pop("project_id")

    if "statuses" in filter_data:
        filter_data["status__in"] = filter_data.pop("statuses")

    qs = qs.filter(**filter_data)
    return qs


class ProjectInvitationFilters(TypedDict, total=False):
    id: UUID
    username_or_email: str
    statuses: list[str]
    project: Project
    project_id: UUID


def _apply_filters_to_queryset(
    qs: QuerySet[ProjectInvitation],
    filters: ProjectInvitationFilters = {},
) -> QuerySet[ProjectInvitation]:
    filter_data = dict(filters.copy())

    if "username_or_email" in filter_data:
        username_or_email = filter_data.pop("username_or_email")
        by_user = Q(user__username__iexact=username_or_email) | Q(user__email__iexact=username_or_email)
        by_email = Q(user__isnull=True, email__iexact=username_or_email)
        qs = qs.filter(by_user | by_email)

    if "project_id" in filter_data:
        filter_data["project__id"] = filter_data.pop("project_id")

    if "statuses" in filter_data:
        filter_data["status__in"] = filter_data.pop("statuses")

    qs = qs.filter(**filter_data)
    return qs


ProjectInvitationSelectRelated = list[
    Literal[
        "user",
        "project",
        "role",
        "workspace",
    ]
]


def _apply_select_related_to_queryset(
    qs: QuerySet[ProjectInvitation],
    select_related: ProjectInvitationSelectRelated,
) -> QuerySet[ProjectInvitation]:
    select_related_data = []

    for key in select_related:
        if key == "workspace":
            select_related_data.append("project__workspace")
        else:
            select_related_data.append(key)

    qs = qs.select_related(*select_related_data)
    return qs


ProjectInvitationOrderBy = list[
    Literal[
        "full_name",
        "email",
    ]
]


def _apply_order_by_to_queryset(
    qs: QuerySet[ProjectInvitation],
    order_by: ProjectInvitationOrderBy,
) -> QuerySet[ProjectInvitation]:
    order_by_data = []

    for key in order_by:
        if key == "full_name":
            order_by_data.append("user__full_name")
        else:
            order_by_data.append(key)

    qs = qs.order_by(*order_by_data)
    return qs


##########################################################
# create project invitation
##########################################################


@sync_to_async
def create_project_invitations(
    objs: list[ProjectInvitation],
    select_related: ProjectInvitationSelectRelated = ["user", "project", "role"],
) -> list[ProjectInvitation]:
    qs = _apply_select_related_to_queryset(qs=DEFAULT_QUERYSET, select_related=select_related)
    return qs.bulk_create(objs=objs)


##########################################################
# get project invitation
##########################################################


@sync_to_async
def get_project_invitation(
    filters: ProjectInvitationFilters = {},
    select_related: ProjectInvitationSelectRelated = ["user", "project", "role"],
) -> ProjectInvitation | None:
    qs = _apply_filters_to_queryset(filters=filters, qs=DEFAULT_QUERYSET)
    qs = _apply_select_related_to_queryset(qs=qs, select_related=select_related)
    try:
        return qs.get()
    except ProjectInvitation.DoesNotExist:
        return None


##########################################################
# get project invitations
##########################################################


@sync_to_async
def get_project_invitations(
    filters: ProjectInvitationListFilters = {},
    offset: int | None = None,
    limit: int | None = None,
    select_related: ProjectInvitationSelectRelated = ["project", "user", "role"],
    order_by: ProjectInvitationOrderBy = ["full_name", "email"],
) -> list[ProjectInvitation]:
    qs = _apply_filters_to_queryset_list(qs=DEFAULT_QUERYSET, filters=filters)
    qs = _apply_select_related_to_queryset(qs=qs, select_related=select_related)
    qs = _apply_order_by_to_queryset(order_by=order_by, qs=qs)

    if limit is not None and offset is not None:
        limit += offset

    return list(qs[offset:limit])


##########################################################
# update invitations
##########################################################


@sync_to_async
def update_project_invitation(invitation: ProjectInvitation) -> ProjectInvitation:
    invitation.save()
    return invitation


@sync_to_async
def bulk_update_project_invitations(objs_to_update: list[ProjectInvitation], fields_to_update: list[str]) -> None:
    ProjectInvitation.objects.bulk_update(objs_to_update, fields_to_update)


@sync_to_async
def update_user_projects_invitations(user: User) -> None:
    ProjectInvitation.objects.filter(email=user.email).update(user=user)


##########################################################
# misc
##########################################################


@sync_to_async
def get_total_project_invitations(
    filters: ProjectInvitationListFilters = {},
) -> int:
    qs = _apply_filters_to_queryset_list(qs=DEFAULT_QUERYSET, filters=filters)
    return qs.count()
