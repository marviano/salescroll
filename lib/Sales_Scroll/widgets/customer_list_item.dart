import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/customer.dart';

class CustomerListItem extends StatefulWidget {
  final Customer customer;
  final VoidCallback? onTap;
  final Future<void> Function()? onBind;
  final Future<void> Function()? onRelease;
  final Future<void> Function()? onCall;
  final Future<void> Function()? onMessage;
  final VoidCallback? onSchedule;

  const CustomerListItem({
    Key? key,
    required this.customer,
    this.onTap,
    this.onBind,
    this.onRelease,
    this.onCall,
    this.onMessage,
    this.onSchedule,
  }) : super(key: key);

  @override
  State<CustomerListItem> createState() => _CustomerListItemState();
}

class _CustomerListItemState extends State<CustomerListItem> {
  bool _isBindLoading = false;
  bool _isReleaseLoading = false;
  bool _isCallLoading = false;
  bool _isMessageLoading = false;
  bool _isExpanded = false;

  bool _shouldShowNotificationDot() {
    print('DEBUG DOT CHECK for ${widget.customer.name}:');
    print('binding_status: ${widget.customer.bindingStatus}');
    print('binding_start_date: ${widget.customer.bindingStartDate}');
    print('last_interaction_date: ${widget.customer.lastInteractionDate}');

    if (widget.customer.bindingStatus == 'bound') {
      // Check initial 3-hour binding period
      if (widget.customer.bindingStartDate != null) {
        final now = DateTime.now();
        final bindingDifference = now.difference(widget.customer.bindingStartDate!);
        print('hours since binding: ${bindingDifference.inHours}');

        // Show dot if bound and no interaction yet
        if (widget.customer.lastInteractionDate == null) {
          print('DOT: showing because no interaction after binding');
          return true;
        }

        // Or if interaction is before binding
        if (widget.customer.lastInteractionDate!.isBefore(widget.customer.bindingStartDate!)) {
          print('DOT: showing because last interaction is before binding');
          return true;
        }
      }

      // Also show dot for overdue follow-ups
      if (widget.customer.isFollowUpDue) {
        print('DOT: showing because follow-up is due');
        return true;
      }
    }

    print('DOT: not showing');
    return false;
  }

  Future<void> _handleBind() async {
    if (widget.onBind == null) return;
    setState(() => _isBindLoading = true);
    try {
      await widget.onBind!();
    } finally {
      if (mounted) setState(() => _isBindLoading = false);
    }
  }

  Future<void> _handleRelease() async {
    if (widget.onRelease == null) return;
    setState(() => _isReleaseLoading = true);
    try {
      await widget.onRelease!();
    } finally {
      if (mounted) setState(() => _isReleaseLoading = false);
    }
  }

  Future<void> _handleCall() async {
    if (widget.onCall == null) return;
    setState(() => _isCallLoading = true);
    try {
      await widget.onCall!();
    } finally {
      if (mounted) setState(() => _isCallLoading = false);
    }
  }

  Future<void> _handleMessage() async {
    if (widget.onMessage == null) return;
    setState(() => _isMessageLoading = true);
    try {
      await widget.onMessage!();
    } finally {
      if (mounted) setState(() => _isMessageLoading = false);
    }
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback? onPressed,
    required bool isLoading,
  }) {
    return IconButton(
      icon: isLoading
          ? SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(color),
        ),
      )
          : Icon(icon, color: color),
      onPressed: isLoading ? null : onPressed,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ExpansionTile(
        key: PageStorageKey(widget.customer.id),
        onExpansionChanged: (expanded) {
          setState(() => _isExpanded = expanded);
        },
        maintainState: true,
        leading: _buildLeadingWithStatus(),
        title: Row(
          children: [
            Expanded(
              child: RichText(
                text: TextSpan(
                  style: DefaultTextStyle.of(context).style,
                  children: [
                    TextSpan(
                      text: widget.customer.name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    if (widget.customer.company != null) ...[
                      const TextSpan(text: ' • '),
                      TextSpan(
                        text: widget.customer.company!,
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                    const TextSpan(text: ' • '),
                    TextSpan(
                      text: widget.customer.bindingStatus == 'bound'
                          ? 'Bound to ${widget.customer.boundToName ?? 'Agent'}'
                          : 'Available',
                      style: TextStyle(
                        color: widget.customer.bindingStatus == 'bound'
                            ? Colors.blue
                            : Colors.green,
                      ),
                    ),
                    if (widget.customer.lastInteractionDate != null) ...[
                      const TextSpan(text: ' • '),
                      TextSpan(
                        text: 'Last: ${DateFormat('MMM d').format(widget.customer.lastInteractionDate!)}',
                        style: TextStyle(color: _getLastContactColor()),
                      ),
                    ],
                  ],
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        trailing: !_isExpanded ? Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildActionButton(
              icon: widget.customer.bindingStatus != 'bound' ? Icons.link : Icons.link_off,
              color: widget.customer.bindingStatus != 'bound' ? Colors.blue : Colors.red,
              onPressed: widget.customer.bindingStatus != 'bound' ? _handleBind : _handleRelease,
              isLoading: _isBindLoading || _isReleaseLoading,
            ),
            _buildActionButton(
              icon: Icons.phone,
              color: Colors.blue,
              onPressed: _handleCall,
              isLoading: _isCallLoading,
            ),
            _buildActionButton(
              icon: Icons.message,
              color: Colors.green,
              onPressed: _handleMessage,
              isLoading: _isMessageLoading,
            ),
          ],
        ) : null,
        children: [
          _buildExpandedDetails(context),
        ],
      ),
    );
  }

  Widget _buildCustomerHeader() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Customer name and company in one row
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.customer.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  if (widget.customer.company != null)
                    Expanded(
                      child: Text(
                        widget.customer.company!,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.end,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              // Status and binding info in one row
              Row(
                children: [
                  _buildStatusChip(),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildBindingChip(),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: _getStatusColor().withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        widget.customer.salesStatus.toUpperCase(),
        style: TextStyle(
          color: _getStatusColor(),
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildBindingChip() {
    final isBinding = widget.customer.bindingStatus == 'bound';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isBinding ? Colors.blue.withOpacity(0.2) : Colors.green.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isBinding ? Icons.link : Icons.person_add,
            size: 12,
            color: isBinding ? Colors.blue : Colors.green,
          ),
          const SizedBox(width: 4),
          Text(
            isBinding
                ? 'Bound to ${widget.customer.boundToName ?? 'Agent'}'
                : 'Available',
            style: TextStyle(
              color: isBinding ? Colors.blue : Colors.green,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // Update the _buildFollowUpIndicator method in CustomerListItem
  // Update the _buildFollowUpIndicator method in CustomerListItem
  Widget _buildFollowUpIndicator() {
    if (widget.customer.nextFollowUpDate != null) {
      final now = DateTime.now();
      final difference = widget.customer.nextFollowUpDate!.difference(now);

      // Check for binding follow-up (3-hour rule)
      if (widget.customer.bindingStatus == 'bound' &&
          widget.customer.bindingStartDate != null) {
        final bindingDifference = now.difference(widget.customer.bindingStartDate!);
        if (bindingDifference.inHours < 3) {
          final minutesLeft = 180 - bindingDifference.inMinutes;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.purple.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.purple.withOpacity(0.5)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.timer, color: Colors.purple, size: 16),
                const SizedBox(width: 4),
                Text(
                  '${minutesLeft.round()}m to contact',
                  style: const TextStyle(
                      color: Colors.purple,
                      fontSize: 12,
                      fontWeight: FontWeight.bold
                  ),
                ),
              ],
            ),
          );
        } else if (bindingDifference.inHours >= 3) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.withOpacity(0.5)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, color: Colors.red, size: 16),
                SizedBox(width: 4),
                Text(
                  'Contact overdue',
                  style: TextStyle(
                      color: Colors.red,
                      fontSize: 12,
                      fontWeight: FontWeight.bold
                  ),
                ),
              ],
            ),
          );
        }
      }

      // Regular follow-up indicators (existing code)
      if (difference.isNegative) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.warning, color: Colors.red, size: 16),
              SizedBox(width: 4),
              Text('Overdue',
                style: TextStyle(color: Colors.red, fontSize: 12),
              ),
            ],
          ),
        );
      } else if (difference.inHours < 3) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.schedule, color: Colors.orange, size: 16),
              const SizedBox(width: 4),
              Text('${difference.inHours}h left',
                style: const TextStyle(color: Colors.orange, fontSize: 12),
              ),
            ],
          ),
        );
      }
    }
    return const SizedBox.shrink();
  }

  Widget _buildLeadingWithStatus() {
    return Stack(
      children: [
        CircleAvatar(
          backgroundColor: _getStatusColor(),
          child: Text(widget.customer.name[0].toUpperCase()),
        ),
        if (_shouldShowNotificationDot())
          Positioned(
            right: -2,  // Adjust if needed
            top: -2,    // Adjust if needed
            child: Container(
              width: 12,          // Bigger for testing
              height: 12,         // Bigger for testing
              decoration: BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),  // Thicker border
                boxShadow: [                                        // Add shadow
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 2,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildBindingInfo() {
    if (widget.customer.bindingStatus != 'bound') {
      return const Text('Available',
          style: TextStyle(color: Colors.green));
    }
    return Text(
      'Bound to ${widget.customer.boundToName ?? widget.customer.boundToUid ?? 'Unknown'}',
      style: const TextStyle(color: Colors.blue),
    );
  }

  Widget _buildLastContactInfo() {
    if (widget.customer.lastInteractionDate == null) {
      return const Text('No previous contact',
          style: TextStyle(color: Colors.grey));
    }
    final contactDate = DateFormat('MMM dd, yyyy').format(widget.customer.lastInteractionDate!);
    final methodText = widget.customer.lastContactMethod != null
        ? ' via ${widget.customer.lastContactMethod}'
        : '';
    return Text(
      'Last contact: $contactDate$methodText',
      style: TextStyle(color: _getLastContactColor()),
    );
  }

  Widget _buildTrailingButtons() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 8.0),
          child: _buildFollowUpIndicator(),
        ),
        Flexible(
          child: Wrap(
            spacing: 4,
            children: [
              if (widget.customer.bindingStatus != 'bound')
                _buildActionButton(
                  icon: Icons.link,
                  color: Colors.blue,
                  onPressed: _handleBind,
                  isLoading: _isBindLoading,
                )
              else
                _buildActionButton(
                  icon: Icons.link_off,
                  color: Colors.red,
                  onPressed: _handleRelease,
                  isLoading: _isReleaseLoading,
                ),
              _buildActionButton(
                icon: Icons.phone,
                color: Colors.blue,
                onPressed: _handleCall,
                isLoading: _isCallLoading,
              ),
              _buildActionButton(
                icon: Icons.message,
                color: Colors.green,
                onPressed: _handleMessage,
                isLoading: _isMessageLoading,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildExpandedDetails(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCustomerSummary(context),
          const Divider(),
          _buildContactHistory(),
          const SizedBox(height: 16),
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildCustomerSummary(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Contact Information',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (_shouldShowNotificationDot()) ...[
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.warning, color: Colors.red.shade700, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.customer.bindingStatus == 'bound' &&
                        widget.customer.bindingStartDate != null &&
                        DateTime.now().difference(widget.customer.bindingStartDate!).inHours >= 3
                        ? 'Initial contact overdue - Customer may be unlinked'
                        : 'Follow-up needed',
                    style: TextStyle(
                      color: Colors.red.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        Text('Phone: ${widget.customer.phoneNumber}'),
        if (widget.customer.company != null)
          Text('Company: ${widget.customer.company}'),
        const SizedBox(height: 8),
        Text('Orders: ${widget.customer.totalOrders} (${widget.customer.completedOrders} completed)'),
        if (widget.customer.nextFollowUpDate != null)
          Text(
            'Next Follow-up: ${DateFormat('MMM dd, yyyy').format(widget.customer.nextFollowUpDate!)}',
            style: TextStyle(
              color: widget.customer.isFollowUpDue ? Colors.red : Colors.green,
              fontWeight: FontWeight.bold,
            ),
          ),
      ],
    );
  }

  Widget _buildStatusMessage() {
    if (widget.customer.bindingStatus == 'bound' &&
        widget.customer.bindingStartDate != null) {
      final bindingDifference = DateTime.now().difference(widget.customer.bindingStartDate!);
      if (bindingDifference.inHours >= 3) {
        return Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.red.withOpacity(0.5)),
          ),
          child: const Row(
            children: [
              Icon(Icons.warning, color: Colors.red, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Initial contact overdue - Customer may be unlinked',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );
      }
    }

    if (widget.customer.isFollowUpDue) {
      return Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.orange.withOpacity(0.5)),
        ),
        child: const Row(
          children: [
            Icon(Icons.schedule, color: Colors.orange, size: 20),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Follow-up overdue',
                style: TextStyle(
                  color: Colors.orange,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildContactHistory() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.customer.lastContactNotes != null && widget.customer.lastContactNotes!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text('Last Notes: ${widget.customer.lastContactNotes}'),
          ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.customer.isFollowUpDue)
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: _buildFollowUpIndicator(),
          ),
        _buildActionButton(
          icon: widget.customer.bindingStatus != 'bound' ? Icons.link : Icons.link_off,
          color: widget.customer.bindingStatus != 'bound' ? Colors.blue : Colors.red,
          onPressed: widget.customer.bindingStatus != 'bound' ? _handleBind : _handleRelease,
          isLoading: _isBindLoading || _isReleaseLoading,
        ),
        _buildActionButton(
          icon: Icons.phone,
          color: Colors.blue,
          onPressed: _handleCall,
          isLoading: _isCallLoading,
        ),
        _buildActionButton(
          icon: Icons.message,
          color: Colors.green,
          onPressed: _handleMessage,
          isLoading: _isMessageLoading,
        ),
      ],
    );
  }

  Color _getStatusColor() {
    switch (widget.customer.salesStatus.toLowerCase()) {
      case 'cold':
        return Colors.blue.shade200;
      case 'warm':
        return Colors.orange.shade200;
      case 'hot':
        return Colors.red.shade200;
      default:
        return Colors.grey.shade200;
    }
  }

  Color _getLastContactColor() {
    if (widget.customer.lastInteractionDate == null) return Colors.grey;
    final daysSinceContact = DateTime.now().difference(widget.customer.lastInteractionDate!).inDays;
    if (daysSinceContact > 25) return Colors.red;
    if (daysSinceContact > 15) return Colors.orange;
    return Colors.green;
  }
}