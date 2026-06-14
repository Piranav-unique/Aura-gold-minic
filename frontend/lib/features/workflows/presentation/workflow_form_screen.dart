import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ags_gold/core/widgets/shared_drawer.dart';
import 'package:ags_gold/features/workflows/domain/workflow.dart';
import 'package:ags_gold/features/workflows/presentation/providers/workflows_provider.dart';

class WorkflowFormScreen extends ConsumerStatefulWidget {
  final String? requestId;

  const WorkflowFormScreen({super.key, this.requestId});

  @override
  ConsumerState<WorkflowFormScreen> createState() => _WorkflowFormScreenState();
}

class _WorkflowFormScreenState extends ConsumerState<WorkflowFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _requestType = 'general';
  bool _saving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadExisting() async {
    final id = widget.requestId;
    if (id == null) return;
    final request = await ref.read(workflowDetailProvider(id).future);
    _titleController.text = request.title;
    _descriptionController.text = request.description ?? '';
    _requestType = request.requestType;
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    if (widget.requestId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadExisting());
    }
  }

  Future<void> _save({bool submit = false}) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final draft = WorkflowRequest(
        id: widget.requestId ?? '',
        requestNumber: '',
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        requestType: _requestType,
        state: 'draft',
        requesterId: '',
        escalationLevel: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      WorkflowRequest saved;
      if (widget.requestId == null) {
        saved = await ref.read(createWorkflowProvider)(draft);
      } else {
        saved = await ref.read(updateWorkflowProvider)(
          WorkflowRequest(
            id: widget.requestId!,
            requestNumber: '',
            title: draft.title,
            description: draft.description,
            requestType: draft.requestType,
            state: 'draft',
            requesterId: '',
            escalationLevel: 0,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );
      }

      if (submit) {
        saved = await ref.read(submitWorkflowProvider)(saved.id);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(submit ? 'Request submitted' : 'Draft saved')),
        );
        context.go('/workflows/${saved.id}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to save: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.requestId != null;

    return ResponsiveNavigationWrapper(
      title: isEdit ? 'Edit request' : 'New workflow request',
      child: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Title'),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Title is required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(labelText: 'Description'),
              maxLines: 4,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _requestType,
              decoration: const InputDecoration(labelText: 'Request type'),
              items: const [
                DropdownMenuItem(value: 'general', child: Text('General')),
                DropdownMenuItem(
                  value: 'transaction',
                  child: Text('Transaction'),
                ),
                DropdownMenuItem(value: 'inventory', child: Text('Inventory')),
                DropdownMenuItem(value: 'customer', child: Text('Customer')),
              ],
              onChanged: (v) => setState(() => _requestType = v ?? 'general'),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : () => _save(),
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(isEdit ? 'Save draft' : 'Create draft'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _saving ? null : () => _save(submit: true),
              child: const Text('Save & submit for approval'),
            ),
          ],
        ),
      ),
    );
  }
}
