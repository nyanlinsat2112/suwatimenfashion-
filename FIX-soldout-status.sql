-- ရှိပြီးသား ပစ္စည်းတွေထဲက Stock 0 ရှိပေမယ့် "Available" ဖြစ်နေတာတွေကို Sold Out အဖြစ် ပြင်ပေးရန်
update products
set status = 'sold_out'
where coalesce(stock_qty, 0) <= 0 and status = 'available';

-- ဘယ်နှခု ပြင်ပြီးလဲ ကြည့်ရန်
select name, stock_qty, status from products where status = 'sold_out';
