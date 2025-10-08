
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'dart:typed_data';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class OrderInvoiceGenerator {
  static Future<void> generateAndDownloadInvoice(
    BuildContext context,
    Orders order,
  ) async {
    try {
      // Generate PDF
      final pdf = await _generateInvoicePDF(order);

      // Show options to user
      await _showDownloadOptions(context, pdf, order.id);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to generate invoice: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  static Future<pw.Document> _generateInvoicePDF(Orders order) async {
    final pdf = pw.Document();

    // Calculate totals
    final subtotal = order.subtotal > 0
        ? order.subtotal
        : order.items.fold<double>(
            0.0, (sum, item) => sum + (item.price * item.quantity));
    final tax = order.taxAmount > 0
        ? order.taxAmount
        : subtotal * 0.1; // Use order tax or 10% fallback
    final shipping = order.deliveryFee > 0
        ? order.deliveryFee
        : 5.99; // Use order delivery fee or fallback
    final total = order.totalAmount;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(20),
                decoration: pw.BoxDecoration(
                  color: PdfColors.blue50,
                  border: pw.Border.all(color: PdfColors.blue200),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'INVOICE',
                      style: pw.TextStyle(
                        fontSize: 28,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue800,
                      ),
                    ),
                    pw.SizedBox(height: 10),
                    pw.Text(
                      'E-Commerce Platform',
                      style: pw.TextStyle(
                        fontSize: 16,
                        color: PdfColors.blue600,
                      ),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 30),

              // Order Information
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Bill To:',
                        style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 5),
                      pw.Text(order.userName,
                          style: const pw.TextStyle(fontSize: 12)),
                      pw.Text(order.userEmail,
                          style: const pw.TextStyle(fontSize: 12)),
                      pw.Text(order.userPhone,
                          style: const pw.TextStyle(fontSize: 12)),
                      if (order.shippingAddress != null) ...[
                        pw.SizedBox(height: 5),
                        pw.Text(
                          'Shipping Address:',
                          style: pw.TextStyle(
                            fontSize: 12,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.Text(order.shippingAddress!,
                            style: const pw.TextStyle(fontSize: 10)),
                      ],
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'Order ID: ${order.orderId.isNotEmpty ? order.orderId : order.id}',
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 5),
                      pw.Text(
                        'Date: ${_formatDate(order.createdAt)}',
                        style: const pw.TextStyle(fontSize: 12),
                      ),
                      pw.Text(
                        'Status: ${order.status.toUpperCase()}',
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                          color: _getStatusColor(order.status),
                        ),
                      ),
                      pw.Text(
                        'Payment: ${order.paymentStatus.toUpperCase()}',
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                          color: _getPaymentStatusColor(order.paymentStatus),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              pw.SizedBox(height: 30),

              // Items Table
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300),
                columnWidths: {
                  0: const pw.FlexColumnWidth(3),
                  1: const pw.FlexColumnWidth(1),
                  2: const pw.FlexColumnWidth(1),
                  3: const pw.FlexColumnWidth(1),
                },
                children: [
                  // Header
                  pw.TableRow(
                    decoration:
                        const pw.BoxDecoration(color: PdfColors.grey100),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          'Item',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          'Qty',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          'Price (BHD)',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                          textAlign: pw.TextAlign.right,
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          'Total (BHD)',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                          textAlign: pw.TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                  // Items
                  ...order.items.map((item) => pw.TableRow(
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(item.productName),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(
                              '${item.quantity}',
                              textAlign: pw.TextAlign.center,
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(
                              '\₹${item.price.toStringAsFixed(2)}',
                              textAlign: pw.TextAlign.right,
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(
                              '\₹${(item.price * item.quantity).toStringAsFixed(2)}',
                              textAlign: pw.TextAlign.right,
                            ),
                          ),
                        ],
                      )),
                ],
              ),

              pw.SizedBox(height: 20),

              // Totals
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Container(
                  width: 200,
                  child: pw.Column(
                    children: [
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('Subtotal:'),
                          pw.Text('\₹${subtotal.toStringAsFixed(2)}'),
                        ],
                      ),
                      pw.SizedBox(height: 5),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('Tax (10%):'),
                          pw.Text('\₹${tax.toStringAsFixed(2)}'),
                        ],
                      ),
                      pw.SizedBox(height: 5),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('Shipping:'),
                          pw.Text('\₹${shipping.toStringAsFixed(2)}'),
                        ],
                      ),
                      pw.Divider(),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            'Total:',
                            style: pw.TextStyle(
                              fontSize: 16,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.Text(
                            '\₹${total.toStringAsFixed(2)}',
                            style: pw.TextStyle(
                              fontSize: 16,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              pw.Spacer(),

              // Footer
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  border: pw.Border.all(color: PdfColors.grey300),
                ),
                child: pw.Column(
                  children: [
                    pw.Text(
                      'Thank you for your business!',
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 5),
                    pw.Text(
                      'For any questions, please contact support@ecommerce.com',
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf;
  }

  static Future<void> _showDownloadOptions(
    BuildContext context,
    pw.Document pdf,
    String orderId,
  ) async {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Download Invoice',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.preview),
              title: const Text('Preview'),
              subtitle: const Text('View the invoice before downloading'),
              onTap: () async {
                Navigator.pop(context);
                await _previewPDF(context, pdf);
              },
            ),
            ListTile(
              leading: const Icon(Icons.download),
              title: const Text('Download'),
              subtitle: const Text('Save to device'),
              onTap: () async {
                Navigator.pop(context);
                await _downloadPDF(context, pdf, orderId);
              },
            ),
            ListTile(
              leading: const Icon(Icons.share),
              title: const Text('Share'),
              subtitle: const Text('Share via other apps'),
              onTap: () async {
                Navigator.pop(context);
                await _sharePDF(context, pdf, orderId);
              },
            ),
          ],
        ),
      ),
    );
  }

  static Future<void> _previewPDF(BuildContext context, pw.Document pdf) async {
    try {
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to preview PDF: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  static Future<void> _downloadPDF(
    BuildContext context,
    pw.Document pdf,
    String orderId,
  ) async {
    try {
      final bytes = await pdf.save();
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/invoice_$orderId.pdf');
      await file.writeAsBytes(bytes);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Invoice saved to ${file.path}'),
          backgroundColor: Colors.green,
          action: SnackBarAction(
            label: 'Open',
            onPressed: () async {
              // You can implement opening the file here
            },
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save PDF: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  static Future<void> _sharePDF(
    BuildContext context,
    pw.Document pdf,
    String orderId,
  ) async {
    try {
      final bytes = await pdf.save();
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/invoice_$orderId.pdf');
      await file.writeAsBytes(bytes);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Invoice for Order $orderId',
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to share PDF: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  static String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  static PdfColor _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return PdfColors.green;
      case 'pending':
        return PdfColors.orange;
      case 'cancelled':
        return PdfColors.red;
      default:
        return PdfColors.grey;
    }
  }

  static PdfColor _getPaymentStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'paid':
        return PdfColors.green;
      case 'pending':
        return PdfColors.orange;
      case 'failed':
        return PdfColors.red;
      default:
        return PdfColors.grey;
    }
  }
}

// Order and OrderItem classes (if not already defined elsewhere)
class Orders {
  final String id;
  final String orderId;
  final String userId;
  final String userName;
  final String userEmail;
  final String userPhone;
  final List<OrderItem> items;
  final double totalAmount;
  final double subtotal;
  final double deliveryFee;
  final double taxAmount;
  final String status;
  final String paymentStatus;
  final String paymentMethod;
  final String? shippingAddress;
  final DateTime createdAt;

  Orders({
    required this.id,
    required this.orderId,
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.userPhone,
    required this.items,
    required this.totalAmount,
    required this.subtotal,
    required this.deliveryFee,
    required this.taxAmount,
    required this.status,
    required this.paymentStatus,
    required this.paymentMethod,
    this.shippingAddress,
    required this.createdAt,
  });

  factory Orders.fromJson(Map<String, dynamic> json) {
    // Handle user data from populated field or direct fields
    final userData = json['userId'] is Map ? json['userId'] : null;
    final addressData = json['address'] ?? {};

    return Orders(
      id: json['_id'] ?? json['id'] ?? '',
      orderId: json['orderId'] ?? '',
      userId: userData?['_id'] ?? json['userId'] ?? '',
      userName: userData?['name'] ?? json['userName'] ?? '',
      userEmail: userData?['email'] ?? json['userEmail'] ?? '',
      userPhone:
          userData?['phone'] ?? json['userPhone'] ?? addressData['phone'] ?? '',
      items: (json['items'] as List? ?? [])
          .map((item) => OrderItem.fromJson(item))
          .toList(),
      totalAmount: (json['totalAmount'] ?? 0).toDouble(),
      subtotal: (json['subtotal'] ?? 0).toDouble(),
      deliveryFee: (json['deliveryFee'] ?? 0).toDouble(),
      taxAmount: (json['taxAmount'] ?? 0).toDouble(),
      status: json['orderStatus'] ?? json['status'] ?? 'pending',
      paymentStatus: json['paymentStatus'] ?? 'pending',
      paymentMethod: json['paymentMethod'] ?? 'cod',
      shippingAddress: addressData.isNotEmpty
          ? '${addressData['address']}, ${addressData['city']}, ${addressData['state']} ${addressData['pincode']}'
          : json['shippingAddress'],
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
    );
  }
}

class OrderItem {
  final String productId;
  final String productName;
  final double price;
  final int quantity;
  final String? imageUrl;
  final String? sellerId;
  final String? sellerName;

  OrderItem({
    required this.productId,
    required this.productName,
    required this.price,
    required this.quantity,
    this.imageUrl,
    this.sellerId,
    this.sellerName,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      productId: json['itemId'] ?? json['productId'] ?? '',
      productName: json['name'] ?? json['productName'] ?? '',
      price: (json['price'] ?? 0).toDouble(),
      quantity: json['quantity'] ?? 1,
      imageUrl: json['imageUrl'],
      sellerId: json['sellerId'],
      sellerName: json['sellerName'],
    );
  }
}
