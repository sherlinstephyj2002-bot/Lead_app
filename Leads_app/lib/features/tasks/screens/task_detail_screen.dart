import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../shared/models/task_model.dart';
import '../../../shared/providers/providers.dart';
import '../../../constants/user_roles.dart';
import '../../../shared/utils/app_notification.dart';

class TaskDetailScreen extends ConsumerWidget {
  final TaskModel task;

  const TaskDetailScreen({
    super.key,
    required this.task,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final isAdmin = user?.role == UserRoles.companyAdmin;
    final isAssigned = task.assignedToId == user?.uid;

    Color badgeColor;
    Color textColor;
    IconData statusIcon;

    switch (task.status) {
      case 'Completed':
        badgeColor = const Color(0xFFDCFCE7);
        textColor = const Color(0xFF15803D);
        statusIcon = Icons.check_circle_rounded;
        break;
      case 'In Progress':
        badgeColor = const Color(0xFFEFF6FF);
        textColor = const Color(0xFF1D4ED8);
        statusIcon = Icons.timelapse_rounded;
        break;
      default:
        badgeColor = const Color(0xFFFFF7ED);
        textColor = const Color(0xFFC2410C);
        statusIcon = Icons.radio_button_unchecked_rounded;
    }

    final isOverdue =
        task.dueDate.isBefore(DateTime.now()) && task.status != 'Completed';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Task Details'),
        actions: [
          if (isAdmin)
            PopupMenuButton(
              itemBuilder: (context) => [
                PopupMenuItem(
                  child: const Text('Edit'),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (ctx) => TaskFormScreen(taskToEdit: task),
                      ),
                    );
                  },
                ),
                PopupMenuItem(
                  child: const Text('Delete'),
                  onTap: () => _showDeleteConfirmation(context, ref),
                ),
              ],
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: badgeColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: textColor.withAlpha(51)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(statusIcon, color: textColor, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Status',
                              style: TextStyle(
                                fontSize: 12,
                                color: textColor.withAlpha(179),
                              ),
                            ),
                            Text(
                              task.status,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Title
            Text(
              'Title',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: const Color(0xFF94A3B8),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              task.title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),

            const SizedBox(height: 20),

            // Description
            if (task.description.isNotEmpty) ...[
              Text(
                'Description',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: const Color(0xFF94A3B8),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Text(
                  task.description,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF475569),
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Assigned To
            Text(
              'Assigned To',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: const Color(0xFF94A3B8),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.person_outline_rounded,
                    size: 16,
                    color: Color(0xFF94A3B8),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    task.assignedTo,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Due Date
            Text(
              'Due Date',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: const Color(0xFF94A3B8),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: isOverdue ? const Color(0xFFFEE2E2) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isOverdue ? const Color(0xFFFCA5A5) : const Color(0xFFE2E8F0),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_today_rounded,
                    size: 16,
                    color: isOverdue ? const Color(0xFFEF4444) : const Color(0xFF94A3B8),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DateFormat('EEEE, dd MMM yyyy').format(task.dueDate),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: isOverdue
                              ? const Color(0xFFEF4444)
                              : const Color(0xFF1E293B),
                        ),
                      ),
                      if (isOverdue)
                        Text(
                          'Overdue',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFFEF4444),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Created At
            Text(
              'Created',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: const Color(0xFF94A3B8),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.access_time_rounded,
                    size: 16,
                    color: Color(0xFF94A3B8),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    DateFormat('dd MMM yyyy, hh:mm a').format(task.createdAt),
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF475569),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Action buttons
            if (isAssigned && task.status == 'Pending')
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    await ref
                        .read(tasksProvider.notifier)
                        .updateTaskStatus(task.taskId, 'In Progress');
                    if (context.mounted) {
                      Navigator.pop(context);
                      AppNotification.showSuccess(context, 'Task started!');
                    }
                  },
                  icon: const Icon(Icons.timelapse_rounded),
                  label: const Text('Start Task'),
                ),
              )
            else if (isAssigned && task.status == 'In Progress')
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    await ref
                        .read(tasksProvider.notifier)
                        .updateTaskStatus(task.taskId, 'Completed');
                    if (context.mounted) {
                      Navigator.pop(context);
                      AppNotification.showSuccess(context, 'Task completed!');
                    }
                  },
                  icon: const Icon(Icons.check_circle_outline_rounded),
                  label: const Text('Mark Completed'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Task?'),
        content: const Text('Are you sure you want to delete this task? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await ref.read(tasksProvider.notifier).deleteTask(task.taskId);
                if (context.mounted) {
                  Navigator.pop(ctx);
                  Navigator.pop(context);
                  AppNotification.showSuccess(context, 'Task deleted successfully!');
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

// Task Form Screen for editing
class TaskFormScreen extends ConsumerStatefulWidget {
  final TaskModel? taskToEdit;

  const TaskFormScreen({
    super.key,
    this.taskToEdit,
  });

  @override
  ConsumerState<TaskFormScreen> createState() => _TaskFormScreenState();
}

class _TaskFormScreenState extends ConsumerState<TaskFormScreen> {
  late TextEditingController _titleController;
  late TextEditingController _descController;
  late DateTime _selectedDue;
  late String _selectedEmpId;
  late String _selectedEmpName;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.taskToEdit != null) {
      _titleController = TextEditingController(text: widget.taskToEdit!.title);
      _descController = TextEditingController(text: widget.taskToEdit!.description);
      _selectedDue = widget.taskToEdit!.dueDate;
      _selectedEmpId = widget.taskToEdit!.assignedToId;
      _selectedEmpName = widget.taskToEdit!.assignedTo;
    } else {
      _titleController = TextEditingController();
      _descController = TextEditingController();
      _selectedDue = DateTime.now().add(const Duration(days: 1));
      final user = ref.read(authProvider).user;
      _selectedEmpId = user?.uid ?? '';
      _selectedEmpName = user?.name ?? '';
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.taskToEdit != null ? 'Edit Task' : 'Add Task'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title field
            Text(
              'Task Title *',
              style: Theme.of(context).textTheme.labelMedium,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                hintText: 'Enter task title',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),

            const SizedBox(height: 16),

            // Description field
            Text(
              'Description',
              style: Theme.of(context).textTheme.labelMedium,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _descController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Enter task description',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),

            const SizedBox(height: 16),

            // Assignee dropdown
            Text(
              'Assign To *',
              style: Theme.of(context).textTheme.labelMedium,
            ),
            const SizedBox(height: 8),
            ref.watch(companyEmployeesProvider).when(
              data: (employees) {
                final currentUser = ref.watch(authProvider).user;
                final allAssignees = [
                  if (currentUser != null) currentUser,
                  ...employees,
                ];
                final uniqueAssignees =
                    {for (var e in allAssignees) e.uid: e}.values.toList();

                return DropdownButtonFormField<String>(
                  value: _selectedEmpId.isEmpty ? null : _selectedEmpId,
                  decoration: InputDecoration(
                    border:
                        OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  items: uniqueAssignees
                      .map((emp) => DropdownMenuItem(
                            value: emp.uid,
                            child: Text(emp.uid == currentUser?.uid
                                ? '${emp.name} (You)'
                                : emp.name),
                          ))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) {
                      final selected =
                          uniqueAssignees.firstWhere((e) => e.uid == val);
                      setState(() {
                        _selectedEmpId = selected.uid;
                        _selectedEmpName = selected.name;
                      });
                    }
                  },
                );
              },
              loading: () => const CircularProgressIndicator(),
              error: (err, _) => Text('Error: $err',
                  style: const TextStyle(color: Colors.red)),
            ),

            const SizedBox(height: 16),

            // Due date picker
            Text(
              'Due Date *',
              style: Theme.of(context).textTheme.labelMedium,
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _selectedDue,
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (picked != null) {
                  setState(() => _selectedDue = picked);
                }
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_rounded,
                        size: 16, color: Color(0xFF64748B)),
                    const SizedBox(width: 8),
                    Text(
                      'Due: ${_selectedDue.day}/${_selectedDue.month}/${_selectedDue.year}',
                      style: const TextStyle(
                          color: Color(0xFF1E293B), fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Save button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading || _titleController.text.isEmpty
                    ? null
                    : () async {
                        setState(() => _isLoading = true);
                        try {
                          if (widget.taskToEdit != null) {
                            await ref.read(tasksProvider.notifier).editTask(
                              widget.taskToEdit!.taskId,
                              _titleController.text.trim(),
                              _descController.text.trim(),
                              _selectedDue,
                              _selectedEmpName,
                              _selectedEmpId,
                            );
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Task updated successfully!')),
                              );
                              Navigator.pop(context);
                              Navigator.pop(context);
                            }
                          } else {
                            await ref.read(tasksProvider.notifier).addTask(
                              _titleController.text.trim(),
                              _descController.text.trim(),
                              _selectedDue,
                              _selectedEmpName,
                              _selectedEmpId,
                            );
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Task created successfully!')),
                              );
                              Navigator.pop(context);
                            }
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error: $e')),
                            );
                          }
                        } finally {
                          if (mounted) {
                            setState(() => _isLoading = false);
                          }
                        }
                      },
                child: _isLoading
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(widget.taskToEdit != null
                        ? 'Update Task'
                        : 'Add Task'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
