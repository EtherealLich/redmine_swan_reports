// Обновление списка пользователей с сервера
function update_users(group_id, div) {  
	jQuery.ajax({
	  url: "/reports/get_users",
	  type: "GET",
	  data: {"group_id" : group_id},
	  dataType: "html",
	  success: function(data) {
		div.html(data);
	  }
	});
}