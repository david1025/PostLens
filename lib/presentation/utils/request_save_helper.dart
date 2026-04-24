import 'package:post_lens/core/utils/toast_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/collection_model.dart';
import '../../domain/models/http_request_model.dart';
import '../providers/collection_provider.dart';
import '../providers/request_provider.dart';
import '../widgets/save_request_dialog.dart';

CollectionModel _addNodeToCollection(
  CollectionModel collection,
  CollectionNode newNode,
  String requestId,
  String? targetFolderId,
) {
  if (targetFolderId == null) {
    List<CollectionNode> updatedChildren = collection.children.map((child) {
      if (child is CollectionRequest && child.id == requestId) {
        return newNode;
      }
      return child;
    }).toList();

    if (!updatedChildren.any((c) => c.id == newNode.id)) {
      updatedChildren = [...collection.children, newNode];
    }

    return collection.copyWith(children: updatedChildren);
  }

  List<CollectionNode> updateChildren(List<CollectionNode> children) {
    return children.map((child) {
      if (child is CollectionFolder) {
        if (child.id == targetFolderId) {
          List<CollectionNode> updatedFolderChildren = child.children.map((c) {
            if (c is CollectionRequest && c.id == requestId) {
              return newNode;
            }
            return c;
          }).toList();

          if (!updatedFolderChildren.any((c) => c.id == newNode.id)) {
            updatedFolderChildren = [...child.children, newNode];
          }

          return child.copyWith(children: updatedFolderChildren);
        }

        return child.copyWith(children: updateChildren(child.children));
      }

      return child;
    }).toList();
  }

  return collection.copyWith(children: updateChildren(collection.children));
}

Future<HttpRequestModel?> saveRequest(
  BuildContext context,
  WidgetRef ref,
  HttpRequestModel request, {
  bool showSuccessMessage = true,
}) async {
  HttpRequestModel? savedRequest;

  if (request.collectionId != null) {
    final collections = ref.read(collectionsProvider);
    final targetCollection =
        collections.where((c) => c.id == request.collectionId).firstOrNull;

    if (targetCollection == null) {
      if (context.mounted) {
        ToastUtils.showInfo(context, 'Collection not found');
      }
      return null;
    }

    savedRequest = request.copyWith();
    final updatedNode = CollectionRequest(
      id: request.id,
      name: request.name,
      request: savedRequest,
    );
    final updatedCollection = _addNodeToCollection(
      targetCollection,
      updatedNode,
      request.id,
      request.folderId,
    );

    await ref
        .read(collectionsProvider.notifier)
        .updateCollection(updatedCollection);
  } else {
    savedRequest = await showGeneralDialog<HttpRequestModel>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Save Request',
      barrierColor: Colors.black54,
      transitionDuration: Duration.zero,
      pageBuilder: (context, animation, secondaryAnimation) {
        return SaveRequestDialog(request: request);
      },
    );
  }

  if (savedRequest == null) return null;

  ref.read(requestProvider.notifier).markSaved(savedRequest);
  if (showSuccessMessage && context.mounted) {
    ToastUtils.showInfo(context, 'Request saved successfully');
  }

  return savedRequest;
}
