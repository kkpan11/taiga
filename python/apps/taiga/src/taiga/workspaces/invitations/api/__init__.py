# -*- coding: utf-8 -*-
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2023-present Kaleidos INC

from fastapi import Depends, Query, Response
from taiga.base.api import AuthRequest
from taiga.base.api import pagination as api_pagination
from taiga.base.api import responses
from taiga.base.api.pagination import PaginationQuery
from taiga.base.api.permissions import check_permissions
from taiga.base.validators import B64UUID
from taiga.exceptions.api.errors import ERROR_400, ERROR_403, ERROR_404, ERROR_422
from taiga.permissions import IsWorkspaceAdmin
from taiga.routers import routes
from taiga.workspaces.invitations import services as workspaces_invitations_services
from taiga.workspaces.invitations.api.validators import WorkspaceInvitationsValidator
from taiga.workspaces.invitations.models import WorkspaceInvitation
from taiga.workspaces.invitations.serializers import CreateWorkspaceInvitationsSerializer, WorkspaceInvitationSerializer
from taiga.workspaces.workspaces.api import get_workspace_or_404

# PERMISSIONS
CREATE_WORKSPACE_INVITATIONS = IsWorkspaceAdmin()
LIST_WORKSPACE_INVITATIONS = IsWorkspaceAdmin()


# HTTP 200 RESPONSES
CREATE_WORKSPACE_INVITATIONS_200 = responses.http_status_200(model=CreateWorkspaceInvitationsSerializer)


##########################################################
# create workspace invitations
##########################################################


@routes.workspaces_invitations.post(
    "/workspaces/{id}/invitations",
    name="workspace.invitations.create",
    summary="Create workspace invitations",
    responses=CREATE_WORKSPACE_INVITATIONS_200 | ERROR_400 | ERROR_404 | ERROR_422 | ERROR_403,
)
async def create_workspace_invitations(
    request: AuthRequest,
    form: WorkspaceInvitationsValidator,
    id: B64UUID = Query(None, description="the workspace id (B64UUID)"),
) -> CreateWorkspaceInvitationsSerializer:
    """
    Create invitations to a workspace for a list of users (identified either by their username or their email).
    """
    workspace = await get_workspace_or_404(id=id)
    await check_permissions(permissions=CREATE_WORKSPACE_INVITATIONS, user=request.user, obj=workspace)

    return await workspaces_invitations_services.create_workspace_invitations(
        workspace=workspace, invitations=form.get_invitations_dict(), invited_by=request.user
    )


##########################################################
# list workspace invitations
##########################################################


@routes.workspaces_invitations.get(
    "/workspaces/{id}/invitations",
    name="workspace.invitations.list",
    summary="List workspace pending invitations",
    response_model=list[WorkspaceInvitationSerializer],
    responses=ERROR_404 | ERROR_422 | ERROR_403,
)
async def list_workspace_invitations(
    request: AuthRequest,
    response: Response,
    pagination_params: PaginationQuery = Depends(),
    id: B64UUID = Query(None, description="the workspace id (B64UUID)"),
) -> list[WorkspaceInvitation]:
    """
    List (pending) workspace invitations
    """
    workspace = await get_workspace_or_404(id)
    await check_permissions(permissions=LIST_WORKSPACE_INVITATIONS, user=request.user, obj=workspace)

    pagination, invitations = await workspaces_invitations_services.list_paginated_pending_workspace_invitations(
        workspace=workspace, offset=pagination_params.offset, limit=pagination_params.limit
    )

    api_pagination.set_pagination(response=response, pagination=pagination)
    return invitations