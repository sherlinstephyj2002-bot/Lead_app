import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/providers/permissions_provider.dart';
import '../../../shared/models/task_model.dart';
import 'task_detail_screen.dart';
import '../../../constants/user_roles.dart';
import '../../../features/company_admin/providers/company_admin_providers.dart';
import '../../../shared/utils/app_notification.dart';
import '../../../shared/services/app_error_handler.dart';

class TaskListScreen extends ConsumerStatefulWidget {
  const TaskListScreen({super.key});

  @override
  ConsumerState<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends ConsumerState<TaskListScreen> {
  String _selectedFilter = 'All';
  final List<String> _filterChips = ['All', 'Pending', 'In Progress', 'Completed'];
  String _searchQuery = '';
  final _searchController = TextEditingController();
  bool _isSearching = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tasksState = ref.watch(tasksProvider);
    final user = ref.watch(authProvider).user;
    final isAdmin = user?.role == UserRoles.companyAdmin;

    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Search tasks...',
                  hintStyle: TextStyle(color: Colors.white60),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                ),
                onChanged: (val) {
                  setState(() => _searchQuery = val.toLowerCase());
                },
              )
            : const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Tasks', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                  Text('Track your team tasks', style: TextStyle(fontSize: 12, color: Colors.white70)),
                ],
              ),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close_rounded : Icons.search_rounded),
            onPressed: () {
              setState(() {
                if (_isSearching) {
                  _searchQuery = '';
                  _searchController.clear();
                }
                _isSearching = !_isSearching;
              });
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(tasksProvider.notifier).loadTasks();
        },
        child: tasksState.when(
          data: (tasks) {
            var visible = isAdmin
                ? tasks
                : tasks.where((t) => t.assignedToId == user?.uid).toList();

            if (_selectedFilter != 'All') {
              visible = visible.where((t) => t.status == _selectedFilter).toList();
            }

            if (_searchQuery.isNotEmpty) {
              visible = visible
                  .where((t) =>
                      t.title.toLowerCase().contains(_searchQuery) ||
                      t.description.toLowerCase().contains(_searchQuery) ||
                      t.assignedTo.toLowerCase().contains(_searchQuery))
                  .toList();
            }

            return Column(
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: _filterChips.map((chip) {
                      final isSelected = _selectedFilter == chip;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          selected: isSelected,
                          label: Text(chip),
                          onSelected: (_) => setState(() => _selectedFilter = chip),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                Expanded(
                  child: visible.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            SizedBox(height: MediaQuery.of(context).size.height * 0.2),
                            const Icon(Icons.checklist_rounded, size: 60, color: Color(0xFFE2E8F0)),
                            const SizedBox(height: 12),
                            const Center(
                              child: Text('No tasks found', style: TextStyle(color: Colors.grey)),
                            ),
                          ],
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          itemCount: visible.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 12),
                          itemBuilder: (context, index) => GestureDetector(
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (ctx) => TaskDetailScreen(task: visible[index]),
                                ),
                              );
                            },
                            child: _buildTaskCard(context, visible[index]),
                          ),
                        ),
                ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(height: MediaQuery.of(context).size.height * 0.2),
                Center(child: Text('Error loading tasks: $err')),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: (isAdmin && ref.watch(permissionServiceProvider).hasPermission('task_create'))
          ? FloatingActionButton.extended(
              heroTag: "taskFab",
              onPressed: () => _showAddTaskDialog(context),
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text('Add Task'),
            )
          : null,
    );
  }

  Widget _buildTaskCard(BuildContext context, TaskModel task) {
    Color badgeColor;
    Color textColor;
    IconData statusIcon;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    switch (task.status) {
      case 'Completed':
        badgeColor = isDark ? const Color(0xFF14532D) : const Color(0xFFDCFCE7);
        textColor = isDark ? const Color(0xFF86EFAC) : const Color(0xFF15803D);
        statusIcon = Icons.check_circle_rounded;
        break;
      case 'In Progress':
        badgeColor = isDark ? const Color(0xFF1E3A8A) : const Color(0xFFEFF6FF);
        textColor = isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8);
        statusIcon = Icons.timelapse_rounded;
        break;
      default:
        badgeColor = isDark ? const Color(0xFF7C2D12) : const Color(0xFFFFF7ED);
        textColor = isDark ? const Color(0xFFFDBA74) : const Color(0xFFC2410C);
        statusIcon = Icons.radio_button_unchecked_rounded;
    }

    final isOverdue =
        task.dueDate.isBefore(DateTime.now()) && task.status != 'Completed';

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: isDark ? Theme.of(context).cardColor : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isOverdue ? const Color(0xFFFCA5A5) : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          width: isOverdue ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(statusIcon, size: 18, color: textColor),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          task.title,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: isDark ? Colors.white : const Color(0xFF1E293B),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: badgeColor,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    task.status,
                    style: TextStyle(
                        color: textColor,
                        fontSize: 10,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            if (task.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(task.description,
                  style:
                      TextStyle(fontSize: 13, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
            ],
            Divider(height: 20, color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
            Row(
              children: [
                const Icon(Icons.person_outline_rounded,
                    size: 14, color: Color(0xFF94A3B8)),
                const SizedBox(width: 4),
                Text(task.assignedTo,
                    style: TextStyle(
                        fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                const Spacer(),
                Icon(Icons.calendar_today_rounded,
                    size: 14,
                    color: isOverdue
                        ? const Color(0xFFEF4444)
                        : const Color(0xFF94A3B8)),
                const SizedBox(width: 4),
                Text(
                  'Due: ${DateFormat('dd MMM yyyy').format(task.dueDate)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: isOverdue
                        ? const Color(0xFFEF4444)
                        : const Color(0xFF64748B),
                    fontWeight:
                        isOverdue ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ],
            ),
            if (task.status == 'Pending') ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await ref
                        .read(tasksProvider.notifier)
                        .updateTaskStatus(task.taskId, 'In Progress');
                    if (context.mounted) {
                      AppNotification.showSuccess(context, 'Task marked as In Progress.');
                    }
                  },
                  icon: const Icon(Icons.timelapse_rounded, size: 15),
                  label: const Text('Start Task'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF1D4ED8),
                    side: const BorderSide(color: Color(0xFF1D4ED8)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
            ] else if (task.status == 'In Progress') ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await ref
                        .read(tasksProvider.notifier)
                        .updateTaskStatus(task.taskId, 'Completed');
                    if (context.mounted) {
                      AppNotification.showSuccess(context, 'Task marked as Completed.');
                    }
                  },
                  icon:
                      const Icon(Icons.check_circle_outline_rounded, size: 15),
                  label: const Text('Mark Completed'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF10B981),
                    side: const BorderSide(color: Color(0xFF10B981)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
            ],
            if (ref.watch(authProvider).user?.role == UserRoles.companyAdmin && ref.watch(permissionServiceProvider).hasPermission('task_reassign')) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _showReassignTaskDialog(context, task),
                  icon: const Icon(Icons.person_add_alt_1_rounded, size: 15),
                  label: const Text('Reassign Task'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF5B4CF0),
                    side: const BorderSide(color: Color(0xFF5B4CF0)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showReassignTaskDialog(BuildContext context, TaskModel task) {
    final employees = ref.read(adminEmployeesProvider).value ?? [];
    if (employees.isEmpty) {
      AppNotification.showError(context, 'No employees found to reassign.');
      return;
    }

    String? selectedUid = task.assignedToId.isNotEmpty ? task.assignedToId : employees.first.uid;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Reassign Task', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Select an authorized employee to assign this task:', style: TextStyle(fontSize: 13, color: Color(0xFF475569))),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: employees.any((e) => e.uid == selectedUid) ? selectedUid : null,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Assigned Employee', prefixIcon: Icon(Icons.person_outline)),
                items: employees.map((emp) {
                  return DropdownMenuItem<String>(
                    value: emp.uid,
                    child: Text('${emp.name} (${emp.employeeId ?? emp.email})', style: const TextStyle(fontSize: 13)),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setDialogState(() => selectedUid = val);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (selectedUid == null) return;
                final targetEmp = employees.firstWhere((e) => e.uid == selectedUid);
                await ref.read(tasksProvider.notifier).reassignTask(
                  task.taskId,
                  targetEmp.name,
                  targetEmp.uid,
                );
                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                  AppNotification.showSuccess(context, 'Task reassigned to ${targetEmp.name}.');
                }
              },
              child: const Text('Reassign'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddTaskDialog(BuildContext context) {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    DateTime selectedDue = DateTime.now().add(const Duration(days: 1));
    bool isLoading = false;

    final user = ref.read(authProvider).user;
    String selectedEmpId = user?.uid ?? '';
    String selectedEmpName = user?.name ?? '';

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text('Add Task'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: InputDecoration(
                        labelText: 'Task Title *',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: 'Description',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ref.watch(companyEmployeesProvider).when(
                      data: (employees) {
                        final currentUser = ref.watch(authProvider).user;
                        final allAssignees = [
                          ?currentUser,
                          ...employees,
                        ];
                        final uniqueAssignees = {for (var e in allAssignees) e.uid: e}.values.toList();
                        
                        if (selectedEmpId.isEmpty && uniqueAssignees.isNotEmpty) {
                          selectedEmpId = uniqueAssignees.first.uid;
                          selectedEmpName = uniqueAssignees.first.name;
                        }

                        return DropdownButtonFormField<String>(
                          initialValue: selectedEmpId.isEmpty ? null : selectedEmpId,
                          decoration: InputDecoration(
                            labelText: 'Assign To *',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          items: uniqueAssignees.map((emp) => DropdownMenuItem(
                            value: emp.uid,
                            child: Text(emp.uid == currentUser?.uid ? '${emp.name} (You)' : emp.name),
                          )).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              final selected = uniqueAssignees.firstWhere((e) => e.uid == val);
                              setDialogState(() {
                                selectedEmpId = selected.uid;
                                selectedEmpName = selected.name;
                              });
                            }
                          },
                        );
                      },
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (err, _) => Text('Error loading employees: $err', style: const TextStyle(color: Colors.red)),
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: selectedDue,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (picked != null) {
                          setDialogState(() => selectedDue = picked);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade400),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today_rounded, size: 16, color: Color(0xFF64748B)),
                            const SizedBox(width: 8),
                            Text(
                              'Due: ${selectedDue.day}/${selectedDue.month}/${selectedDue.year}',
                              style: const TextStyle(color: Color(0xFF1E293B), fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isLoading || titleController.text.isEmpty || selectedEmpId.isEmpty
                      ? null
                      : () async {
                          setDialogState(() => isLoading = true);
                          try {
                            await ref.read(tasksProvider.notifier).addTask(
                              titleController.text.trim(),
                              descController.text.trim(),
                              selectedDue,
                              selectedEmpName,
                              selectedEmpId,
                            );
                            if (dialogContext.mounted) {
                              Navigator.pop(dialogContext);
                              AppNotification.showSuccess(context, 'Task created successfully!');
                            }
                          } catch (e) {
                            if (dialogContext.mounted) {
                              AppNotification.showError(context, AppErrorHandler.parseError(e));
                            }
                          } finally {
                            if (dialogContext.mounted) {
                              setDialogState(() => isLoading = false);
                            }
                          }
                        },
                  child: isLoading
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Add Task'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
