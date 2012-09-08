$ ->
  $('.pick').click -> startPickIntent()

  $('.edit').click -> startEditIntent()

  $('form').submit ->
    $('input[type="submit"]').prop("disabled",true)
    data = $('.preview').css('background-image').slice(4, -1) # remove 'url(' and ')'
    $('.data-url').attr('value', data) 

  $('.preview').mouseup -> $('.file').trigger('click')

  $('.file').change (e) ->
    file = e.originalEvent.target.files[0]
    if (file and /^image\/(png|jpeg)$/.test(file.type))
      filereader = new FileReader()
      $(filereader).load ->
        $('.preview').css('background-image', 'url("' + filereader.result + '")')
      filereader.readAsDataURL(file)

  onSuccess = (data) ->
    if typeof(data) == "string" && data.match(/^data:/)
      $('.preview').css('background-image', 'url(' + data + ')')
    else
      alert("Sorry!, unsupported data type");

  onError = (data) -> alert(data) if data

  startPickIntent = ->
    intent = new WebKitIntent("http://webintents.org/pick", "image/*")
    window.navigator.webkitStartActivity(intent, onSuccess, onError);

  startEditIntent = ->
    data = $('.preview').css('background-image').slice(4, -1) # remove 'url(' and ')'
    intent = new WebKitIntent("http://webintents.org/edit", "image/*", data)
    window.navigator.webkitStartActivity(intent, onSuccess, onError);
