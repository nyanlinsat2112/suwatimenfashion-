-- ရှိပြီးသား In-Store Order များထဲက Phone Number "-" ဟု ဖြစ်နေတာများကို Empty String ("") အဖြစ် ပြင်ပေးရန်
-- (orders.phone Column မှာ NOT NULL Constraint ရှိနေလို့ NULL မထည့်နိုင်ပါ — Empty String ကတော့ ခွင့်ပြုပါတယ်
--  ဒါမှသာ Customer Management ထဲမှာ Walk-in Customer တစ်ဦးစီကို နာမည်ခွဲပြီး မှန်ကန်စွာ ခွဲခြားပြသနိုင်ပါမည်)
update orders
set phone = ''
where phone = '-' and sale_channel = 'in_store';
