import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:mytogetherapp/features/order/data/models/demo_order_data.dart';

class OrderHistoryCard extends StatefulWidget {
  final DemoOrder order;

  const OrderHistoryCard({
    super.key,
    required this.order,
  });

  @override
  State<OrderHistoryCard> createState() => _OrderHistoryCardState();
}

class _OrderHistoryCardState extends State<OrderHistoryCard> {
  late bool _isRated;
  late int _ratingScore;

  @override
  void initState() {
    super.initState();
    _isRated = widget.order.isRated;
    _ratingScore = widget.order.ratingScore;
  }

  Color get primaryColor => const Color(0xFFED3A72);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildTopRow(),
                const SizedBox(height: 16),
                _buildMiddleRow(),
                const SizedBox(height: 16),
                _buildBottomRow(context),
              ],
            ),
          ),
          if (widget.order.type == 'completed' && widget.order.hasRatingRow) _buildRatingStrip(),
        ],
      ),
    );
  }

  Widget _buildTopRow() {
    Color labelColor = Colors.grey;
    if (widget.order.type == 'completed') labelColor = primaryColor;
    if (widget.order.type == 'active') labelColor = primaryColor;

    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Image.network(
              widget.order.shopLogoUrl,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  Container(color: Colors.grey[200]),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            widget.order.shopName,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Text(
          widget.order.type == 'completed' ? 'Completed' : (widget.order.type == 'cancelled' ? 'Cancelled' : 'Active'),
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: labelColor,
          ),
        ),
      ],
    );
  }

  Widget _buildMiddleRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Row(
            children: _buildThumbnails(),
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              widget.order.priceDisplay,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: primaryColor,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  '${widget.order.itemCount} Items ',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  size: 16,
                  color: Colors.grey[400],
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  List<Widget> _buildThumbnails() {
    List<Widget> thumbs = [];
    int maxDisplayCount = 3;
    bool hasOverflow = widget.order.itemThumbnails.length > maxDisplayCount;

    for (int i = 0; i < (hasOverflow ? maxDisplayCount : widget.order.itemThumbnails.length); i++) {
        bool isLast = i == widget.order.itemThumbnails.length - 1;
        bool isThird = i == maxDisplayCount - 1;

        Widget img = Container(
          width: 60,
          height: 60,
          margin: EdgeInsets.only(right: isLast ? 0 : 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: Colors.grey[100],
          ),
          child: ClipRRect(
             borderRadius: BorderRadius.circular(8),
             child: Image.network(
                widget.order.itemThumbnails[i],
                fit: BoxFit.cover,
                 errorBuilder: (context, error, stackTrace) =>
                  Container(color: Colors.grey[200]),
             ),
          ),
        );

        if (hasOverflow && isThird) {
           thumbs.add(Stack(
             children: [
                img,
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.black.withValues(alpha: 0.6),
                  ),
                  child: Center(
                    child: Text(
                      '+${widget.order.itemThumbnails.length - maxDisplayCount}', // +X overlay
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
             ],
           ));
        } else {
           thumbs.add(img);
        }
    }

    return thumbs;
  }

  Widget _buildBottomRow(BuildContext context) {
    if (widget.order.type == 'active') {
       return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              widget.order.dateDisplay.isEmpty ? 'Order placed' : widget.order.dateDisplay,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: Colors.grey[500],
              ),
            ),
            Container(
               padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
               decoration: BoxDecoration(
                 color: primaryColor.withValues(alpha: 0.1),
                 borderRadius: BorderRadius.circular(100),
               ),
               child: Text(
                 'In Progress',
                 style: GoogleFonts.poppins(
                   fontWeight: FontWeight.w600,
                   fontSize: 12,
                   color: primaryColor,
                 ),
               ),
            ),
          ],
       );
    }

    // For completed and cancelled
    String btnLabel = widget.order.type == 'completed' ? 'Re-order' : 'Buy Again';

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          widget.order.dateDisplay,
          style: GoogleFonts.poppins(
            fontSize: 13,
            color: Colors.grey[500],
          ),
        ),
        ElevatedButton(
           onPressed: () {},
           style: ElevatedButton.styleFrom(
             backgroundColor: primaryColor,
             foregroundColor: Colors.white,
             elevation: 0,
             padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
             shape: RoundedRectangleBorder(
               borderRadius: BorderRadius.circular(100),
             ),
           ),
           child: Text(
             btnLabel,
             style: GoogleFonts.poppins(
               fontWeight: FontWeight.w600,
               fontSize: 13,
             ),
           ),
        ),
      ],
    );
  }

  Widget _buildRatingStrip() {
    return Container(
       padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
       decoration: const BoxDecoration(
          color: Color(0xFFF8FAFC), // Light grey strip
          borderRadius: BorderRadius.only(
             bottomLeft: Radius.circular(16),
             bottomRight: Radius.circular(16),
          ),
       ),
       child: _isRated ? _buildRatedContent() : _buildPromptContent(),
    );
  }

  Widget _buildPromptContent() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'How was your order?',
          style: GoogleFonts.poppins(
             fontSize: 13,
             color: Colors.grey[600],
          ),
        ),
        const SizedBox(width: 12),
        Row(
           children: List.generate(5, (index) => GestureDetector(
              onTap: () {
                setState(() {
                  _ratingScore = index + 1;
                  _isRated = true;
                });
              },
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Icon(Icons.star_border_rounded, size: 24, color: Colors.grey[400]),
              ),
           )),
        ),
      ],
    );
  }

  Widget _buildRatedContent() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'My rating $_ratingScore/5',
           style: GoogleFonts.poppins(
             fontSize: 13,
             color: Colors.grey[600],
          ),
        ),
        const SizedBox(width: 8),
        Icon(Icons.star_rounded, size: 20, color: primaryColor),
      ],
    );
  }
}
