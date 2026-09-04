# KCN Network Member Exit patch
# Run from the Firebase/Flutter project root.
$ErrorActionPreference = 'Stop'

function Save-Text($path, $text) {
    Set-Content -LiteralPath $path -Value $text -Encoding UTF8
}

# ------------------------------------------------------------
# 1) functions/index.js
# ------------------------------------------------------------
$path = '.\functions\index.js'
if (!(Test-Path $path)) { throw "Missing $path" }
$s = Get-Content -Raw -LiteralPath $path

# Prevent future rewards from following an exited member.
$old = @'
    const member = memberSnap.docs[0].data() || {};
    const sponsorId = String(member.sponsorId || '');
'@
$new = @'
    const member = memberSnap.docs[0].data() || {};
    if (String(member.status || '').toLowerCase() === 'exited') break;
    const sponsorId = String(member.sponsorId || '');
'@
if ($s.Contains($old) -and !$s.Contains("status || '').toLowerCase() === 'exited'")) {
    $s = $s.Replace($old, $new)
}

if (!$s.Contains('exports.processNetworkExit =')) {
$function = @'

// ------------------------------------------------------------
// Network Member Exit
// A member may leave the network. Direct children are re-parented
// to the exiting member's original sponsor, and all deeper
// descendants have their displayed level reduced by one.
// Historical orders/rewards are never changed.
// ------------------------------------------------------------
exports.processNetworkExit = onDocumentCreated('network_exit_requests_v3/{requestId}', async (event) => {
  const requestRef = event.data?.ref;
  const request = event.data?.data();
  if (!requestRef || !request) return null;

  const farmerId = String(request.farmerId || '').trim();

  const reject = async (reason) => {
    await requestRef.update({
      status: 'rejected',
      failureReason: reason,
      processedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  };

  if (!farmerId) {
    await reject('Invalid farmerId.');
    return null;
  }

  try {
    const memberRef = db.collection('network_members_v3').doc(farmerId);
    const memberSnap = await memberRef.get();

    if (!memberSnap.exists) throw new Error('Network member not found.');

    const member = memberSnap.data() || {};
    if (String(member.status || '').toLowerCase() === 'exited') {
      throw new Error('Member has already exited.');
    }

    const sponsorId = String(member.sponsorId || '').trim();

    // Root members have no sponsor and cannot exit.
    if (!sponsorId || member.isRootMember === true) {
      throw new Error('Root member cannot exit the network.');
    }

    const sponsorRef = db.collection('network_members_v3').doc(sponsorId);
    const sponsorSnap = await sponsorRef.get();
    if (!sponsorSnap.exists) {
      throw new Error('Original sponsor not found.');
    }

    const sponsor = sponsorSnap.data() || {};
    if (String(sponsor.status || '').toLowerCase() === 'exited') {
      throw new Error('Original sponsor is no longer active.');
    }

    // Read the complete network once, build the tree in memory,
    // then prepare all writes before changing any document.
    const allSnap = await db.collection('network_members_v3').get();
    const byId = new Map();
    const childrenBySponsor = new Map();

    allSnap.forEach((doc) => {
      const data = doc.data() || {};
      byId.set(doc.id, { id: doc.id, data });

      const parentId = String(data.sponsorId || '').trim();
      if (!parentId || parentId === '__EXITED__') return;

      if (!childrenBySponsor.has(parentId)) {
        childrenBySponsor.set(parentId, []);
      }
      childrenBySponsor.get(parentId).push({ id: doc.id, data });
    });

    const directChildren = childrenBySponsor.get(farmerId) || [];

    // Collect every descendant and detect cycles/corrupt links first.
    const descendants = [];
    const queue = [...directChildren];
    const visited = new Set([farmerId]);

    while (queue.length > 0) {
      const node = queue.shift();
      if (visited.has(node.id)) {
        throw new Error('Network tree cycle detected. Exit was not applied.');
      }
      visited.add(node.id);
      descendants.push(node);

      const kids = childrenBySponsor.get(node.id) || [];
      for (const kid of kids) queue.push(kid);

      if (descendants.length > 10000) {
        throw new Error('Network tree is too large for one exit operation.');
      }
    }

    const writes = [];

    // First: move direct children to the exiting member's original sponsor.
    for (const child of directChildren) {
      const oldLevel = n(child.data.level || 1);
      writes.push({
        ref: db.collection('network_members_v3').doc(child.id),
        data: {
          sponsorId,
          sponsorName: sponsor.memberName || sponsor.name || '',
          sponsorKcnId: sponsor.kcnId || '',
          level: Math.max(1, Math.floor(oldLevel) - 1),
          reparentedAfterExit: farmerId,
          reparentedAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
      });
    }

    // Deeper descendants stay under the same parent, but their level
    // becomes one level closer to the root.
    for (const node of descendants) {
      if (directChildren.some((x) => x.id === node.id)) continue;

      const oldLevel = n(node.data.level || 1);
      writes.push({
        ref: db.collection('network_members_v3').doc(node.id),
        data: {
          level: Math.max(1, Math.floor(oldLevel) - 1),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
      });
    }

    // Finally mark the exiting member as exited and remove it from
    // the active tree. Historical rewards/orders are untouched.
    writes.push({
      ref: memberRef,
      data: {
        status: 'exited',
        isActive: false,
        sponsorId: '__EXITED__',
        level: 0,
        exitSponsorId: sponsorId,
        exitSponsorName: sponsor.memberName || sponsor.name || '',
        exitSponsorKcnId: sponsor.kcnId || '',
        exitedAt: admin.firestore.FieldValue.serverTimestamp(),
        exitRequestId: event.params.requestId,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
    });

    // Firestore batch limit is 500 writes. Keep margin for safety.
    for (let i = 0; i < writes.length; i += 450) {
      const batch = db.batch();
      const chunk = writes.slice(i, i + 450);
      for (const op of chunk) {
        batch.update(op.ref, op.data);
      }
      await batch.commit();
    }

    await requestRef.update({
      status: 'completed',
      processedAt: admin.firestore.FieldValue.serverTimestamp(),
      reparentedDirectChildren: directChildren.length,
      adjustedDescendants: descendants.length,
      originalSponsorId: sponsorId,
    });

    return null;
  } catch (error) {
    await reject(error.message || 'Network exit failed.');
    return null;
  }
});
'@
    Add-Content -LiteralPath $path -Value $function -Encoding UTF8
}
Save-Text $path $s

# ------------------------------------------------------------
# 2) firestore.rules
# ------------------------------------------------------------
$path = '.\firestore.rules'
if (!(Test-Path $path)) { throw "Missing $path" }
$s = Get-Content -Raw -LiteralPath $path

if (!$s.Contains('match /network_exit_requests_v3/{id}')) {
$rulesBlock = @'

    // Farmer network exit requests.
    // Client can only create/read its own request.
    // Cloud Functions uses Admin SDK for server-side processing.
    match /network_exit_requests_v3/{id} {
      allow create: if isFarmer()
        && id == request.auth.uid
        && request.resource.data.farmerId == request.auth.uid
        && request.resource.data.status == 'pending';

      allow get: if isAdmin()
        || (isFarmer() && id == request.auth.uid);

      allow list: if isAdmin();
      allow update, delete: if isAdmin();
    }

'@
    $pattern = '(?s)(\n\s*//\s*DENY EVERYTHING ELSE)'
    if ([regex]::IsMatch($s, $pattern)) {
        $s = [regex]::Replace(
            $s,
            $pattern,
            [System.Text.RegularExpressions.MatchEvaluator]{ param($m) "`n$rulesBlock$($m.Value)" },
            1
        )
    } else {
        throw "Could not find the DENY EVERYTHING ELSE section in firestore.rules."
    }
}
Save-Text $path $s

# ------------------------------------------------------------
# 3) lib/app.dart
# ------------------------------------------------------------
$path = '.\lib\app.dart'
if (!(Test-Path $path)) { throw "Missing $path" }
$s = Get-Content -Raw -LiteralPath $path

# Make Admin Network count/tree show active members only.
$oldAdmin = "        final members = snap.data!.docs;"
$newAdmin = @'
        final members = snap.data!.docs
            .where((d) => d.data()['status']?.toString() != 'exited')
            .toList();
'@
if ($s.Contains($oldAdmin)) {
    $s = $s.Replace($oldAdmin, $newAdmin)
}

$pattern = '(?s)class FarmerNetworkPage extends StatelessWidget \{.*?\n\}\n(?=class FarmerCreditPage)'
if (![regex]::IsMatch($s, $pattern)) {
    throw "Could not locate FarmerNetworkPage block."
}

$newPage = @'
class FarmerNetworkPage extends StatefulWidget {
  const FarmerNetworkPage({super.key});

  @override
  State<FarmerNetworkPage> createState() => _FarmerNetworkPageState();
}

class _FarmerNetworkPageState extends State<FarmerNetworkPage> {
  bool _submitting = false;

  Future<void> _requestExit(Map<String, dynamic> member) async {
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null || _submitting) return;

    final sponsorId = member['sponsorId']?.toString() ?? '';
    final isRoot = sponsorId.isEmpty || member['isRootMember'] == true;

    if (isRoot) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Root member cannot exit the network.')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Exit Network?'),
        content: const Text(
          'If you exit, your direct members will automatically move '
          'under your original sponsor. The rest of the tree will stay '
          'connected and its levels will be adjusted. Your old orders '
          'and rewards will remain unchanged.\n\n'
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Exit Network'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _submitting = true);

    final requestRef = FirebaseFirestore.instance
        .collection('network_exit_requests_v3')
        .doc(uid);

    try {
      await requestRef.create({
        'farmerId': uid,
        'farmerName': member['memberName']?.toString() ?? '',
        'kcnId': member['kcnId']?.toString() ?? '',
        'sponsorId': sponsorId,
        'status': 'pending',
        'requestedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Exit request submitted. Your network will be adjusted automatically.',
            ),
          ),
        );
      }
    } on FirebaseException catch (e) {
      if (mounted) {
        final message = e.code == 'already-exists'
            ? 'An exit request already exists or this member has already exited.'
            : 'Exit request failed: ${e.message ?? e.code}';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Exit request failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null) return const Center(child: Text('Not signed in.'));

    final db = FirebaseFirestore.instance;
    final memberRef = db.collection(Collections.networkMembers).doc(uid);
    final exitRef = db.collection('network_exit_requests_v3').doc(uid);

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: memberRef.snapshots(),
      builder: (context, memberSnap) {
        if (memberSnap.hasError) {
          return Center(
            child: Text('Unable to load network.\n${memberSnap.error}'),
          );
        }
        if (!memberSnap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!memberSnap.data!.exists) {
          return const Center(child: Text('Network membership not found.'));
        }

        final member = memberSnap.data!.data() ?? <String, dynamic>{};
        final status = member['status']?.toString().toLowerCase() ?? 'active';
        final sponsorId = member['sponsorId']?.toString() ?? '';
        final isRoot =
            sponsorId.isEmpty || member['isRootMember'] == true;
        final exited = status == 'exited';

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: exitRef.snapshots(),
          builder: (context, exitSnap) {
            final exitData = exitSnap.data?.data();
            final exitStatus = exitData?['status']?.toString().toLowerCase();

            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: db
                  .collection(Collections.networkMembers)
                  .where('sponsorId', isEqualTo: uid)
                  .snapshots(),
              builder: (context, snap) {
                if (snap.hasError) {
                  return Center(
                    child: Text('Unable to load network.\n${snap.error}'),
                  );
                }

                final docs = snap.data?.docs ?? const [];

                String? bannerText;
                if (exited) {
                  bannerText =
                      'You have exited the KCN Network. Your previous '
                      'orders and rewards remain unchanged.';
                } else if (exitStatus == 'pending') {
                  bannerText =
                      'Exit request is being processed. Your network '
                      'will be adjusted automatically.';
                } else if (exitStatus == 'rejected') {
                  bannerText =
                      'Your exit request could not be completed. '
                      'Please contact Admin.';
                } else if (isRoot) {
                  bannerText = 'Root member cannot exit the network.';
                }

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'My Network',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'KCN ID: ${member['kcnId'] ?? '-'}',
                            ),
                            Text(
                              'Direct Members: ${docs.length}',
                            ),
                            if (bannerText != null) ...[
                              const SizedBox(height: 12),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .outline,
                                  ),
                                ),
                                child: Text(bannerText),
                              ),
                            ],
                            if (!exited &&
                                !isRoot &&
                                exitStatus != 'pending' &&
                                exitStatus != 'rejected') ...[
                              const SizedBox(height: 14),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: _submitting
                                      ? null
                                      : () => _requestExit(member),
                                  icon: _submitting
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(Icons.logout),
                                  label: Text(
                                    _submitting
                                        ? 'Submitting...'
                                        : 'Exit Network',
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (docs.isEmpty)
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(18),
                          child: Text('No direct members yet.'),
                        ),
                      )
                    else
                      ...docs.map(
                        (d) {
                          final data = d.data();
                          return Card(
                            child: ListTile(
                              leading: const Icon(Icons.person_outline),
                              title: Text(
                                data['memberName']?.toString() ?? '-',
                              ),
                              subtitle: Text(
                                'KCN: ${data['kcnId']?.toString() ?? '-'}',
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }
}

'@

$s = [regex]::Replace(
    $s,
    $pattern,
    [System.Text.RegularExpressions.MatchEvaluator]{ param($m) $newPage },
    1
)
Save-Text $path $s

Write-Host ''
Write-Host 'KCN Network Member Exit patch applied successfully.' -ForegroundColor Green
Write-Host 'Changed: functions/index.js, firestore.rules, lib/app.dart'
Write-Host ''
